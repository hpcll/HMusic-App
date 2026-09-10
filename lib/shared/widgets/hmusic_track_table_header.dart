import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import 'hmusic_track_columns.dart';

class HMusicTrackTableHeader extends StatelessWidget {
  const HMusicTrackTableHeader({required this.actionsWidth, super.key});

  final double actionsWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showTrackColumns(context, constraints.maxWidth)) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: DefaultTextStyle(
            style: TextStyle(fontSize: 12, color: context.palette.muted),
            child: HMusicTrackColumns(
              song: const Padding(
                padding: EdgeInsets.only(left: 57),
                child: Text('歌曲'),
              ),
              artistAlbum: const Text('歌手 / 专辑'),
              duration: const Text('时长'),
              source: const Text('来源'),
              actions: const SizedBox.shrink(),
              actionsWidth: actionsWidth,
            ),
          ),
        );
      },
    );
  }
}
