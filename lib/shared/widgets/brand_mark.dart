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

  // 显示高度（字标整体高；宽 ≈ 2.94 × 高）。
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Image.asset(
      dark
          ? 'assets/icon/brand-wordmark-dark.png'
          : 'assets/icon/brand-wordmark-light.png',
      height: size,
      fit: BoxFit.contain,
      cacheHeight: (size * MediaQuery.devicePixelRatioOf(context)).round(),
    );
  }
}
