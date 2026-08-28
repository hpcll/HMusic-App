import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/features/auth/data/api_auth_repository.dart';
import 'package:hmusic/features/auth/data/auth_repository.dart';
import 'package:hmusic/features/auth/models/auth_session.dart';
import 'package:hmusic/features/auth/models/auth_status.dart';
import 'package:hmusic/features/auth/models/auth_user.dart';
import 'package:hmusic/features/auth/models/auth_view_state.dart';
import 'package:hmusic/features/auth/view_models/auth_view_model.dart';

// 登录提交只 catch ApiFailure 时，平台层异常（钥匙串/通道失效）会整个逃出去，
// 把状态永久留在 submitting——线上表现就是按钮一直显示「处理中…」，点不动也不报错。
class _ThrowingAuthRepository implements AuthRepository {
  _ThrowingAuthRepository(this.failure);

  final Object failure;

  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => throw failure;

  @override
  Future<AuthSession> setup({
    required String username,
    required String password,
  }) async => throw failure;

  @override
  Future<AuthStatus> status() async => throw failure;
}

class _OkAuthRepository implements AuthRepository {
  @override
  Future<AuthSession> login({
    required String username,
    required String password,
  }) async => const AuthSession(
    accessToken: 'tok',
    user: AuthUser(id: 'u1', username: 'admin'),
  );

  @override
  Future<AuthSession> setup({
    required String username,
    required String password,
  }) async => login(username: username, password: password);

  @override
  Future<AuthStatus> status() async =>
      const AuthStatus(initialized: true, authenticated: false);
}

ProviderContainer _container(AuthRepository repository) {
  final container = ProviderContainer(
    overrides: [authRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('平台异常不再把提交态卡死，报错并回到可重试状态', () async {
    final container = _container(
      _ThrowingAuthRepository(
        PlatformException(code: 'channel-error', message: 'no handler'),
      ),
    );

    final ok = await container
        .read(authViewModelProvider.notifier)
        .submit(username: 'admin', password: 'password-123');

    final state = container.read(authViewModelProvider);
    expect(ok, isFalse);
    expect(state.isBusy, isFalse);
    expect(state.status, AuthSubmissionStatus.idle);
    expect(state.errorMessage, contains('channel-error'));
  });

  test('ApiFailure 仍按原文案展示', () async {
    final container = _container(
      _ThrowingAuthRepository(
        const ApiFailure(
          kind: ApiFailureKind.unauthorized,
          message: '用户名或密码错误',
        ),
      ),
    );

    await container
        .read(authViewModelProvider.notifier)
        .submit(username: 'admin', password: 'password-123');

    expect(container.read(authViewModelProvider).errorMessage, '用户名或密码错误');
  });

  test('loadStatus 撞上平台异常也要退出加载态', () async {
    final container = _container(
      _ThrowingAuthRepository(MissingPluginException('no impl')),
    );

    await container.read(authViewModelProvider.notifier).loadStatus();

    final state = container.read(authViewModelProvider);
    expect(state.isBusy, isFalse);
    expect(state.errorMessage, isNotNull);
  });

  test('正常登录仍然成功并进入已认证态', () async {
    final container = _container(_OkAuthRepository());

    final ok = await container
        .read(authViewModelProvider.notifier)
        .submit(username: 'admin', password: 'password-123');

    expect(ok, isTrue);
    expect(container.read(authViewModelProvider).isAuthenticated, isTrue);
  });
}
