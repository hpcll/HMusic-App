import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/app/theme/hmusic_theme.dart';
import 'package:hmusic/core/direct/auth/mi_direct_login_result.dart';
import 'package:hmusic/core/direct/auth/mi_passport_result.dart';
import 'package:hmusic/core/direct/mi_direct_account_repository.dart';
import 'package:hmusic/core/direct/mi_direct_providers.dart';
import 'package:hmusic/core/direct/mi_direct_session.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/playback/playback_mode.dart';
import 'package:hmusic/core/playback/playback_mode_controller.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/direct_auth/views/direct_login_page.dart';
import 'package:mocktail/mocktail.dart';

class _Account extends Mock implements MiDirectAccountRepository {}

void main() {
  late _Account account;
  late ProviderContainer container;
  late Uint8List captchaBytes;
  setUpAll(() async {
    registerFallbackValue(
      MiDirectSession(userId: '12345', serviceToken: 'fixture-session-token'),
    );
    captchaBytes = await File('assets/icon/brand-mark.png').readAsBytes();
  });
  setUp(() async {
    account = _Account();
    when(() => account.restore()).thenAnswer((_) async => null);
    when(() => account.cancelLogin()).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        miDirectAccountRepositoryProvider.overrideWithValue(account),
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
      ],
    );
    await container
        .read(playbackModeProvider.notifier)
        .select(PlaybackMode.direct);
  });
  tearDown(() => container.dispose());

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: DirectLoginPage.path,
      routes: [
        GoRoute(
          path: DirectLoginPage.path,
          builder: (_, _) => const DirectLoginPage(),
        ),
        GoRoute(
          path: '/search-tab',
          builder: (_, _) => const Scaffold(body: Text('搜索已就绪')),
        ),
        GoRoute(
          path: '/connect',
          builder: (_, _) => const Scaffold(body: Text('服务器连接')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: HMusicTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, '登录小米账号');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'password errors stay retryable and successful login opens search',
    (tester) async {
      when(
        () => account.loginPassword(
          account: 'listener',
          password: 'fixture-password',
          captchaCode: null,
        ),
      ).thenThrow(
        const ApiFailure(kind: ApiFailureKind.unauthorized, message: '账号或密码错误'),
      );
      await pump(tester);
      await tester.enterText(find.byType(TextField).at(0), 'listener');
      await tester.enterText(find.byType(TextField).at(1), 'fixture-password');
      await submit(tester);
      expect(find.text('账号或密码错误'), findsOneWidget);
      when(
        () => account.loginPassword(
          account: 'listener',
          password: 'fixture-password',
          captchaCode: null,
        ),
      ).thenAnswer(
        (_) async => MiDirectLoginAuthenticated(
          MiDirectAccount(userId: '12345', devices: []),
        ),
      );
      await submit(tester);
      expect(find.text('搜索已就绪'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'captcha challenge and refresh remain usable on a narrow large-text screen',
    (tester) async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.captcha,
        url: Uri.parse('https://account.xiaomi.com/pass/getCode'),
      );
      when(
        () =>
            account.loginPassword(account: '', password: '', captchaCode: null),
      ).thenAnswer((_) async => MiDirectLoginChallenge(challenge));
      when(
        () => account.captchaImage(challenge),
      ).thenAnswer((_) async => captchaBytes);
      await pump(tester, scale: 1.7);
      await submit(tester);
      expect(find.widgetWithText(TextField, '图片验证码'), findsOneWidget);
      final refresh = find.text('换一张验证码');
      await tester.ensureVisible(refresh);
      await tester.tap(refresh);
      await tester.pumpAndSettle();
      verify(() => account.captchaImage(challenge)).called(2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'credential import hides its token and displays validation errors without overflow',
    (tester) async {
      when(() => account.importSession(any())).thenThrow(
        const ApiFailure(
          kind: ApiFailureKind.unauthorized,
          message: '凭据已失效，请重新导入',
        ),
      );
      await pump(tester, scale: 1.7);
      final expand = find.text('使用已有的小米凭据');
      await tester.ensureVisible(expand);
      await tester.tap(expand);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '小米 userId'),
        '12345',
      );
      final token = find.widgetWithText(TextField, 'serviceToken');
      await tester.enterText(token, 'fixture-session-token');
      expect(tester.widget<TextField>(token).obscureText, isTrue);
      final button = find.text('验证并导入');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('凭据已失效，请重新导入'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'web verification returns its authenticated result to the App and opens search',
    (tester) async {
      final challenge = MiPassportChallenge(
        kind: MiChallengeKind.identity,
        url: Uri.parse('https://account.xiaomi.com/fe/service/login'),
      );
      when(
        () =>
            account.loginPassword(account: '', password: '', captchaCode: null),
      ).thenAnswer((_) async => MiDirectLoginChallenge(challenge));
      when(() => account.verifyWeb(challenge)).thenAnswer(
        (_) async => MiDirectLoginAuthenticated(
          MiDirectAccount(userId: '12345', devices: []),
        ),
      );
      await pump(tester);
      await submit(tester);
      expect(find.text('打开小米验证页面'), findsOneWidget);
      expect(find.widgetWithText(TextField, '图片验证码'), findsNothing);
      verifyNever(() => account.captchaImage(challenge));
      final verifyButton = find.text('打开小米验证页面');
      await tester.ensureVisible(verifyButton);
      await tester.tap(verifyButton);
      await tester.pumpAndSettle();
      verify(() => account.verifyWeb(challenge)).called(1);
      expect(find.text('搜索已就绪'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid image shows a retry message and refresh replaces it', (
    tester,
  ) async {
    final challenge = MiPassportChallenge(
      kind: MiChallengeKind.captcha,
      url: Uri.parse('https://account.xiaomi.com/pass/getCode'),
    );
    when(
      () => account.loginPassword(account: '', password: '', captchaCode: null),
    ).thenAnswer((_) async => MiDirectLoginChallenge(challenge));
    when(
      () => account.captchaImage(challenge),
    ).thenAnswer((_) async => Uint8List.fromList('not an image'.codeUnits));
    await pump(tester);
    await submit(tester);
    expect(find.text('验证码图片无法显示，请换一张重试'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.widgetWithText(TextField, '图片验证码'), 'old-code');
    when(
      () => account.captchaImage(challenge),
    ).thenAnswer((_) async => captchaBytes);
    final refresh = find.text('换一张验证码');
    await tester.ensureVisible(refresh);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    expect(find.text('验证码图片无法显示，请换一张重试'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '图片验证码'))
          .controller!
          .text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
