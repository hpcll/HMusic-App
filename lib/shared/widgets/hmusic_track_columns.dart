import 'package:flutter/material.dart';

// 搜索与曲库的同一列规格。用实际内容宽度与字体判断，窄桌面和大字可退两行模式。
bool showTrackColumns(BuildContext context, double width) =>
    width >= 720 * MediaQuery.textScalerOf(context).scale(14) / 14;

class HMusicTrackColumns extends StatelessWidget {
  const HMusicTrackColumns({
    required this.song,
    required this.artistAlbum,
    required this.duration,
    required this.source,
    required this.actions,
    required this.actionsWidth,
    super.key,
  });

  final Widget song;
  final Widget artistAlbum;
  final Widget duration;
  final Widget source;
  final Widget actions;
  final double actionsWidth;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        children: <Widget>[
          Expanded(flex: 4, child: song),
          const SizedBox(width: 20),
          Expanded(flex: 3, child: artistAlbum),
          const SizedBox(width: 16),
          if (constraints.maxWidth >= 1000 * scale) ...<Widget>[
            SizedBox(width: 90 * scale, child: source),
            const SizedBox(width: 16),
          ],
          SizedBox(width: 66 * scale, child: duration),
          const SizedBox(width: 12),
          SizedBox(width: actionsWidth, child: actions),
        ],
      ),
    );
  }
}
