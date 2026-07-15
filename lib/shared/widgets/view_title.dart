import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';

// 页面大标题，对齐 web .view-title：衬线 28px（窄屏 22px）/ weight 600 / text-strong。
// 这是这套 UI 的「刊物腔调」灵魂，务必用衬线（NotoSerifSC），不用无衬线糊弄。
class ViewTitle extends StatelessWidget {
  const ViewTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final narrow = MediaQuery.sizeOf(context).width < 860;
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'NotoSerifSC',
        fontSize: narrow ? 22 : 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.28,
        height: 1.2,
        color: palette.textStrong,
      ),
    );
  }
}
