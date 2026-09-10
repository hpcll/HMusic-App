import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'chrome_fixture.dart';

// 可选视觉验收覆盖真实 Flutter 外壳；正常测试不加载宿主字体、不写文件。
void registerChromeVisualCaptures() {
  const directory = String.fromEnvironment('HMUSIC_CHROME_CAPTURE_DIR');
  if (directory.isEmpty) return;
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  for (final (name, idle, dark, scale, width) in [
    ('playing-light', false, false, 1.0, 390.0),
    ('idle-light', true, false, 1.0, 390.0),
    ('playing-dark', false, true, 1.0, 390.0),
    ('large-text', false, false, 2.0, 360.0),
    ('narrow', false, false, 1.0, 320.0),
  ]) {
    testWidgets('底部外壳视觉 $name', (tester) async {
      await pumpChrome(
        tester,
        PlaybackUiFixture(state: idle ? idlePlayback() : uiPlayback()),
        dark: dark,
        scale: scale,
        width: width,
      );
      await _capture(tester, '$directory/$name-expanded.png');
      final gesture = await beginChromeScroll(tester);
      for (var frame = 0; frame <= 20; frame++) {
        if (frame > 0) await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        if (name == 'playing-light') {
          await _capture(
            tester,
            '$directory/shrink-${frame.toString().padLeft(2, '0')}.png',
          );
        }
      }
      await _capture(tester, '$directory/$name-compact.png');
      await gesture.moveBy(const Offset(0, 60));
      await tester.pump();
      for (var frame = 0; frame <= 20; frame++) {
        if (frame > 0) await tester.pump(const Duration(milliseconds: 16));
        expect(tester.takeException(), isNull);
        if (name == 'playing-light') {
          await _capture(
            tester,
            '$directory/expand-${frame.toString().padLeft(2, '0')}.png',
          );
        }
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _loadFonts() async {
  final serif = FontLoader('NotoSerifSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/NotoSerifSC-SemiBold.ttf'));
  await serif.load();
  await (FontLoader(
    'MaterialIcons',
  )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  final systemFont = File('/System/Library/Fonts/STHeiti Light.ttc');
  final bytes = systemFont.existsSync()
      ? ByteData.sublistView(await systemFont.readAsBytes())
      : await rootBundle.load('assets/fonts/NotoSerifSC-Medium.ttf');
  await (FontLoader('Roboto')..addFont(Future.value(bytes))).load();
  await (FontLoader('PingFang SC')..addFont(Future.value(bytes))).load();
}

Future<void> _capture(WidgetTester tester, String path) async {
  final surface = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(chromeCaptureKey),
  );
  await tester.runAsync(() async {
    final image = await surface.toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}
