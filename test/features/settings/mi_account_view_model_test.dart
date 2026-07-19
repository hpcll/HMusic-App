import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/settings/data/api_mi_account_repository.dart';
import 'package:hmusic/features/settings/models/mi_account.dart';
import 'package:hmusic/features/settings/models/mi_account_state.dart';
import 'package:hmusic/features/settings/view_models/mi_account_view_model.dart';

import 'support/fake_mi_account_repository.dart';

ProviderContainer _container(FakeMiAccountRepository repository) {
  final container = ProviderContainer(
    overrides: [miAccountRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('未登录：登录面板直接展示，不需要更换入口', () async {
    final repository = FakeMiAccountRepository();
    final container = _container(repository);
    final viewModel = container.read(miAccountViewModelProvider.notifier);

    await viewModel.loadStatus();
    final state = container.read(miAccountViewModelProvider);
    expect(state.loggedIn, isFalse);
    expect(state.showLoginPanel, isTrue);
  });

  test('已登录：默认收起登录面板，翻转「更换账号」后展开并回到扫码页', () async {
    final repository = FakeMiAccountRepository(
      current: const MiStatus(loggedIn: true, accountMasked: '138****0000'),
    );
    final container = _container(repository);
    final viewModel = container.read(miAccountViewModelProvider.notifier);

    await viewModel.loadStatus();
    var state = container.read(miAccountViewModelProvider);
    expect(state.loggedIn, isTrue);
    expect(state.showLoginPanel, isFalse);

    viewModel.switchTab(MiTab.password);
    viewModel.toggleChangeAccount();
    state = container.read(miAccountViewModelProvider);
    expect(state.showLoginPanel, isTrue);
    // 展开必须从干净的扫码页开始，不残留上次通道。
    expect(state.tab, MiTab.qr);
    expect(state.qrStage, MiQrStage.idle);

    viewModel.toggleChangeAccount();
    expect(container.read(miAccountViewModelProvider).showLoginPanel, isFalse);
  });

  test('更换账号中扫码登录成功：loadStatus 自动收起面板', () async {
    final repository = FakeMiAccountRepository(
      current: const MiStatus(loggedIn: true, accountMasked: '138****0000'),
    );
    final container = _container(repository);
    final viewModel = container.read(miAccountViewModelProvider.notifier);

    await viewModel.loadStatus();
    viewModel.toggleChangeAccount();
    expect(container.read(miAccountViewModelProvider).showLoginPanel, isTrue);

    // 模拟新账号登录成功后的状态回读。
    repository.current = const MiStatus(
      loggedIn: true,
      accountMasked: '139****1111',
    );
    await viewModel.loadStatus();
    final state = container.read(miAccountViewModelProvider);
    expect(state.status?.accountMasked, '139****1111');
    expect(state.changingAccount, isFalse);
    expect(state.showLoginPanel, isFalse);
  });

  test('退出登录：状态回未登录，面板随之直接展示', () async {
    final repository = FakeMiAccountRepository(
      current: const MiStatus(loggedIn: true, accountMasked: '138****0000'),
    );
    final container = _container(repository);
    final viewModel = container.read(miAccountViewModelProvider.notifier);

    await viewModel.loadStatus();
    await viewModel.logout();
    final state = container.read(miAccountViewModelProvider);
    expect(repository.calls, contains('logout'));
    expect(state.loggedIn, isFalse);
    expect(state.showLoginPanel, isTrue);
  });
}
