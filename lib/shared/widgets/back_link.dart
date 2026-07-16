import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';

// 详情页返回链接：chevron + 上级页名，三处详情页（榜单/歌单/设置子页）共用。
// 统一替代裸 TextButton('‹ xx')——那版字符箭头小、命中区不足。
// 几何：高 44（10+24+10，够 iOS HIG 触摸目标）；chevron 字形在 24 框内自带
// ~6pt 左留白，整体左移抵消，箭头尖端恰好压在页面 16 基线上（Transform
// 同步平移命中区，不产生越界热区）。
class BackLink extends StatelessWidget {
  const BackLink({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Transform.translate(
      offset: const Offset(-6, 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 10, 12, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.chevron_left_rounded,
                size: 24,
                color: palette.textStrong,
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: palette.textStrong,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
