import 'dart:async';

import 'package:flutter/material.dart';

// 品牌音符字形（青绿 H-note，与 web favicon / app icon 同图形）。
// 源: assets/icon/hmusic-glyph.svg → 打包 brand-mark.png（透明底 256 高）。
// 尺寸语义: size = 显示高度；字形宽高比 ≈ 0.69，宽度自适应。
class BrandMark extends StatelessWidget {
  const BrandMark({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/brand-mark.png',
      height: size,
      fit: BoxFit.contain,
      // 按展示高度解码（同 hmusic_cover 的 cacheWidth 纪律）。
      cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}

// 完整品牌字标：原字标 SVG 的原始几何（字形与 Music 的穿插、间距、比例
// 都是原作者调定的，手拼 Row 复刻不出火苗旗与 M 的咬合），仅把字母路径
// 换成墨色导出——青绿只留音符，通体绿会腻；墨色随主题分两张图。
// 生成方式见 tool/generate_icons.py 同目录说明；源 SVG 在 ../HMusic/assets。
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({required this.size, super.key});

  // 连接页开场与登录页共用的展示高度。warmUp() 预解码的就是这个高度——
  // ResizeImage 的缓存键含解码尺寸，换个 size 就是另一条缓存条目，预热白做。
  static const double standardSize = 56;

  // 显示高度（字标整体高；宽 ≈ 2.94 × 高）。
  final double size;

  static String _assetOf(Brightness brightness) => brightness == Brightness.dark
      ? 'assets/icon/brand-wordmark-dark.png'
      : 'assets/icon/brand-wordmark-light.png';

  // 渲染和预热必须拿到**同一个** provider（同一个缓存键），所以只在这一处造它：
  // 少一个 cacheHeight、差一档 dpr，预热就落到另一条缓存上，真机表现是图片照旧
  // 迟到，而单测又看不出来。
  static ImageProvider providerOf({
    required Brightness brightness,
    required double devicePixelRatio,
    double size = standardSize,
  }) => ResizeImage.resizeIfNeeded(
    null,
    (size * devicePixelRatio).round(),
    AssetImage(_assetOf(brightness)),
  );

  // 首帧之前把字标解好塞进 imageCache（main() 里 await）。
  //
  // 为什么非要预热：Image 在字节读完 + 解码完成前**什么都不画**，开场第 1 幕
  // 淡入的就是一个空盒子。真机冷启动时这张 1348×458 的 PNG 往往要等到淡入走完
  // 才就位，于是满不透明地"啪"一下出现，紧接着被推到锚点——用户看到的「icon 不
  // 是慢慢显示，是我一打开它就在，然后突然滑到最后的位置」。
  //
  // 取不到也不许把启动卡住：超时就放行，最坏退化成原来的「图片迟到」。
  static Future<void> warmUp() {
    final platform = WidgetsBinding.instance.platformDispatcher;
    final ImageProvider provider = providerOf(
      brightness: platform.platformBrightness,
      devicePixelRatio: platform.implicitView?.devicePixelRatio ?? 1,
    );
    // 与 precacheImage 同一套做法，只是它要 BuildContext，而这里比首帧还早。
    final Completer<void> done = Completer<void>();
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);
    final ImageStreamListener listener = ImageStreamListener(
      (ImageInfo image, bool synchronous) {
        // 解码结果留在 imageCache 里，这个句柄用不上。
        image.dispose();
        if (!done.isCompleted) done.complete();
      },
      onError: (Object error, StackTrace? stack) {
        if (!done.isCompleted) done.complete();
      },
    );
    stream.addListener(listener);
    unawaited(done.future.then((_) => stream.removeListener(listener)));
    return done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
  }

  @override
  Widget build(BuildContext context) {
    return Image(
      image: providerOf(
        brightness: Theme.of(context).brightness,
        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
        size: size,
      ),
      height: size,
      fit: BoxFit.contain,
    );
  }
}
