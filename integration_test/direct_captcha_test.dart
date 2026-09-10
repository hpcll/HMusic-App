import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/core/direct/auth/mi_passport_captcha.dart';
import 'package:hmusic/core/direct/auth/mi_passport_http.dart';
import 'package:hmusic/features/direct_auth/widgets/direct_captcha_image.dart';
import 'package:integration_test/integration_test.dart';

import 'support/native_test_report.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const report = NativeTestReport('direct-captcha');
  final measurements = <String, Object?>{};
  unawaited(
    binding.allTestsPassed.future.then(
      (passed) => report.write(passed ? 'passed' : 'failed', {
        ...measurements,
        'failures': binding.failureMethodsDetails
            .map((f) => f.toString())
            .toList(),
      }),
    ),
  );

  testWidgets('public Xiaomi captcha loads, decodes and refreshes on device', (
    tester,
  ) async {
    await report.write('started');
    final http = MiPassportHttp();
    addTearDown(http.close);
    final captcha = MiPassportCaptcha(http);
    final uri = MiPassportHttp.accountUri('/pass/getCode?icodeType=antispam');
    // 仅访问公开图片端点，不提交账号、密码或验证码答案。
    for (var attempt = 1; attempt <= 2; attempt++) {
      final bytes = await captcha.load(uri);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThan(0));
      expect(frame.image.height, greaterThan(0));
      measurements['image$attempt'] = {
        'bytes': bytes.length,
        'width': frame.image.width,
        'height': frame.image.height,
      };
      frame.image.dispose();
      codec.dispose();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  const Text('HMusic 验证码图片显示验证'),
                  DirectCaptchaImage(bytes: bytes, loading: false),
                ],
              ),
            ),
          ),
        ),
      );
      await precacheImage(
        MemoryImage(bytes),
        tester.element(find.byType(Scaffold)),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
      expect(find.text('验证码图片无法显示，请换一张重试'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
