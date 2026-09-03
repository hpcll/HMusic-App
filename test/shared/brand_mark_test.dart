import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hmusic/shared/widgets/brand_mark.dart';

// 用户反馈（真机安装 0.1.5 测试包）：「appicon 不是慢慢显示的，我打开他就显示了，
// 然后突然有一个动画滑动到最后的位置，感觉有点怪怪的不连贯」。
//
// 原因之一：字标是 1348×458 的 PNG，Image 在解码完成前**什么都不画**，开场第 1 幕
// 淡入的是个空盒子；真机冷启动时图片往往等淡入走完才就位，于是满不透明地"啪"一下
// 出现，紧接着被推到锚点。修法是 main() 在首帧之前 await BrandWordmark.warmUp()。
//
// 预热的成败全看**缓存键对不对**：ResizeImage 进 imageCache 用的键含解码尺寸，
// 渲染侧差一档 dpr、或者哪个页面自己写了别的 size，预热就落到另一条缓存上——真机
// 表现是图片照旧迟到，而普通单测什么都看不出来。这里机械守这一层。
//
// 注意比的是 obtainKey 的结果而不是两个 provider：ResizeImage 自己没有实现 ==
// （父类按引用比），provider 相等与否说明不了缓存命中与否，键才是真的。
void main() {
  Future<Object> keyOf(ImageProvider provider) =>
      provider.obtainKey(ImageConfiguration.empty);

  Future<ImageProvider> renderedProvider(
    WidgetTester tester,
    Brightness brightness,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: const Scaffold(
          body: Center(child: BrandWordmark(size: BrandWordmark.standardSize)),
        ),
      ),
    );
    // MaterialApp 内部是 AnimatedTheme：同一个测试里换主题要 200ms 才真正切过去，
    // 半路上 ThemeData.lerp 的 brightness 还是旧值，不 settle 就会量到上一张图。
    await tester.pumpAndSettle();
    return tester.widget<Image>(find.byType(Image)).image;
  }

  // warmUp() 取的就是这两个平台值，测试里照抄一遍，键必须一致。
  ImageProvider warmedProvider(Brightness brightness) =>
      BrandWordmark.providerOf(
        brightness: brightness,
        devicePixelRatio:
            WidgetsBinding
                .instance
                .platformDispatcher
                .implicitView
                ?.devicePixelRatio ??
            1,
      );

  for (final Brightness brightness in Brightness.values) {
    testWidgets('$brightness 字标渲染与预热落在同一个缓存键上', (tester) async {
      expect(
        await keyOf(await renderedProvider(tester, brightness)),
        await keyOf(warmedProvider(brightness)),
      );
    });
  }

  // 亮暗两张图不能取错，否则暗色下会显示墨色字标（深底上几乎看不见）。
  testWidgets('亮暗各取各的字标图', (tester) async {
    // ResizeImage 的 toString 只有 'ResizeImage()'，要看图名得剥到里面那层。
    String assetOf(ImageProvider provider) =>
        (provider as ResizeImage).imageProvider.toString();

    final ImageProvider light = await renderedProvider(
      tester,
      Brightness.light,
    );
    final ImageProvider dark = await renderedProvider(tester, Brightness.dark);
    expect(await keyOf(light), isNot(await keyOf(dark)));
    expect(assetOf(light), contains('brand-wordmark-light.png'));
    expect(assetOf(dark), contains('brand-wordmark-dark.png'));
  });

  // 预热真正要买到的东西：**首帧就有像素**。缓存里已有解好的图时 ImageStream 会
  // 同步回调，RawImage 第一帧就拿得到 image；没预热则第一帧 image 为 null（画的
  // 是空盒子），也就是用户看到的"图片迟到、然后啪一下出现"。
  testWidgets('预热之后首帧就有像素，不再淡入空盒子', (tester) async {
    await BrandWordmark.warmUp();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          brightness:
              WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ),
        home: const Scaffold(
          body: Center(child: BrandWordmark(size: BrandWordmark.standardSize)),
        ),
      ),
    );
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
  });

  // 预热必须在首帧之前完成，也就是 runApp 之前 await 掉；放到 runApp 之后（或者
  // 忘了 await）等于没预热——第 1 幕照旧淡入空盒子。
  test('main() 在 runApp 之前 await 预热', () {
    final String source = File('lib/main.dart').readAsStringSync();
    final int warm = source.indexOf('await BrandWordmark.warmUp()');
    final int run = source.indexOf('runApp(');
    expect(warm, greaterThan(-1), reason: 'main.dart 里没有 await 预热');
    expect(run, greaterThan(warm), reason: '预热必须排在 runApp 之前');
  });

  // 两个页面共用一个尺寸常量，预热才只需要解一次；谁自己写死数字，那一页就退回
  // 「图片迟到」。
  test('连接页与登录页都用 BrandWordmark.standardSize', () {
    for (final String path in const <String>[
      'lib/features/connection/widgets/connection_scenes.dart',
      'lib/features/auth/views/auth_page.dart',
    ]) {
      final String source = File(path).readAsStringSync();
      expect(source, contains('BrandWordmark.standardSize'), reason: path);
      expect(
        RegExp(r'BrandWordmark\(size: \d').hasMatch(source),
        isFalse,
        reason: '$path 写死了字标尺寸',
      );
    }
  });
}
