import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/features/settings/data/api_mi_account_repository.dart';
import 'package:hmusic/features/settings/models/mi_account.dart';
import 'package:hmusic/features/settings/view_models/mi_session_watch_view_model.dart';

import 'support/fake_mi_account_repository.dart';

// 过期横幅状态机：check 走 verify 真校验且限频；过期 → showBanner；
// dismiss 本次运行内静音；重新登录后横幅消退且 dismissed 复位。
ProviderContainer _container(FakeMiAccountRepository repository) {
  final container = ProviderContainer(
    overrides: [miAccountRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);
  return container;
}

const MiStatus _expired = MiStatus(
  loggedIn: false,
  sessionExpired: true,
  accountMasked: '138****0000',
);

void main() {
  test('check 请求服务端真校验，过期时亮横幅', () async {
    final repository = FakeMiAccountRepository(current: _expired);
    final container = _container(repository);
    final watcher = container.read(miSessionWatchProvider.notifier);

    await watcher.check();
    expect(repository.calls, <String>['status:verify']);
    final state = container.read(miSessionWatchProvider);
    expect(state.showBanner, isTrue);
    expect(state.accountMasked, '138****0000');
  });

  test('check 限频：窗口内重复调用不再发请求', () async {
    final repository = FakeMiAccountRepository(current: _expired);
    final container = _container(repository);
    final watcher = container.read(miSessionWatchProvider.notifier);

    await watcher.check();
    await watcher.check();
    expect(repository.calls, <String>['status:verify']);
  });

  test('dismiss 本次运行内静音；重新登录后复位', () async {
    final repository = FakeMiAccountRepository(current: _expired);
    final container = _container(repository);
    final watcher = container.read(miSessionWatchProvider.notifier);

    await watcher.check();
    watcher.dismiss();
    expect(container.read(miSessionWatchProvider).showBanner, isFalse);

    // 重新登录：过期解除，dismissed 复位——下次再过期仍会提示。
    watcher.applyStatus(
      const MiStatus(loggedIn: true, accountMasked: '138****0000'),
    );
    var state = container.read(miSessionWatchProvider);
    expect(state.expired, isFalse);
    expect(state.showBanner, isFalse);

    watcher.applyStatus(_expired);
    state = container.read(miSessionWatchProvider);
    expect(state.showBanner, isTrue);
  });

  test('未登录但非过期（主动退出/从未登录）不亮横幅', () async {
    final repository = FakeMiAccountRepository();
    final container = _container(repository);
    final watcher = container.read(miSessionWatchProvider.notifier);

    await watcher.check();
    expect(container.read(miSessionWatchProvider).showBanner, isFalse);
  });

  test('refreshQuick 走快照读取（不带 verify）', () async {
    final repository = FakeMiAccountRepository(current: _expired);
    final container = _container(repository);
    final watcher = container.read(miSessionWatchProvider.notifier);

    await watcher.refreshQuick();
    expect(repository.calls, <String>['status']);
    expect(container.read(miSessionWatchProvider).showBanner, isTrue);
  });

  test('旧 Server 无 sessionExpired 字段：解码默认 false，不误报', () {
    final status = MiStatus.fromJson(const <String, Object?>{
      'loggedIn': true,
      'accountMasked': '138****0000',
    });
    expect(status.sessionExpired, isFalse);

    final expired = MiStatus.fromJson(const <String, Object?>{
      'loggedIn': false,
      'sessionExpired': true,
    });
    expect(expired.sessionExpired, isTrue);
  });
}
