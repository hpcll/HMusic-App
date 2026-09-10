import 'package:flutter/material.dart';

import '../../app/theme/hmusic_palette.dart';
import '../../core/models/hmusic_track.dart';
import '../formatters/duration_format.dart';
import 'hmusic_cover.dart';
import 'hmusic_track_columns.dart';
import 'hmusic_track_row.dart';

// 一份 track 与动作驱动两种呈现；这里只布局，不持有播放/下载状态。
class HMusicAdaptiveTrackRow extends StatelessWidget {
  const HMusicAdaptiveTrackRow({
    required this.track,
    required this.actions,
    required this.actionsWidth,
    this.onTap,
    this.showDivider = true,
    super.key,
  });

  final HMusicTrack track;
  final List<Widget> actions;
  final double actionsWidth;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!showTrackColumns(context, constraints.maxWidth)) {
          return HMusicTrackRow(
            title: track.title,
            subtitle: <String>[
              track.artist.isEmpty ? '未知歌手' : track.artist,
              if (track.album?.isNotEmpty ?? false) track.album!,
            ].join(' · '),
            coverUrl: track.coverUrl,
            onTap: onTap,
            actions: actions,
            showDivider: showDivider,
          );
        }
        return _columns(context);
      },
    );
  }

  Widget _columns(BuildContext context) {
    final palette = context.palette;
    final duration = track.durationMs;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: palette.lineSoft))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: HMusicTrackColumns(
              song: _song(palette.textStrong),
              artistAlbum: _artistAlbum(palette.text, palette.muted),
              duration: _text(
                duration == null || duration <= 0
                    ? '—'
                    : formatDuration(Duration(milliseconds: duration)),
                palette.muted,
              ),
              source: _text(_sourceLabel(track.source), palette.muted),
              actions: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  for (var i = 0; i < actions.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(width: 6),
                    actions[i],
                  ],
                ],
              ),
              actionsWidth: actionsWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _song(Color color) => Row(
    children: <Widget>[
      HMusicCover(url: track.coverUrl),
      const SizedBox(width: 13),
      Expanded(child: _text(track.title, color, strong: true)),
    ],
  );

  Widget _artistAlbum(Color text, Color muted) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      _text(track.artist.isEmpty ? '未知歌手' : track.artist, text),
      _text(track.album?.isNotEmpty == true ? track.album! : '—', muted),
    ],
  );

  Widget _text(String text, Color color, {bool strong = false}) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      fontSize: strong ? 14 : 12.5,
      fontWeight: strong ? FontWeight.w500 : FontWeight.normal,
      color: color,
    ),
  );

  String _sourceLabel(String source) => switch (source) {
    'wy' => '网易云',
    'tx' => 'QQ音乐',
    'kw' => '酷我',
    'local' => 'NAS',
    'manual' => '手工曲目',
    'apple' => 'Apple Music',
    '' => '—',
    _ => source,
  };
}
