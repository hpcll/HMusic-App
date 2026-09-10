import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../models/chart.dart';
import 'chart_card_header.dart';
import 'chart_preview_song.dart';

// 榜单卡片：方封面、两行榜名和分层的 Top3；固定包络按实际字号计算。
class ChartCard extends StatelessWidget {
  const ChartCard({
    required this.chart,
    required this.preview,
    required this.pending,
    required this.onOpen,
    required this.onPlayEntry,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final Chart chart;
  final List<ChartEntry>? preview;
  final bool pending;
  final VoidCallback onOpen;
  final void Function(ChartEntry entry) onPlayEntry;
  final String? errorMessage;
  final VoidCallback? onRetry;

  static double heightFor(TextScaler scaler) =>
      28 +
      ChartCardHeader.heightFor(scaler) +
      12 +
      ChartPreviewSong.heightFor(scaler) * 3;

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final cover = preview?.isNotEmpty == true ? preview!.first.coverUrl : null;
    return HMusicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ChartCardHeader(chart: chart, cover: cover),
          const SizedBox(height: 12),
          SizedBox(
            height: ChartPreviewSong.heightFor(scaler) * 3,
            child: AnimatedSwitcher(
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: _preview(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final palette = context.palette;
    if (pending && preview == null) {
      return Column(
        children: <Widget>[
          for (final width in const <double>[0.9, 0.72, 0.55])
            SizedBox(
              height: ChartPreviewSong.heightFor(
                MediaQuery.textScalerOf(context),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: width,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: palette.panelSecondary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final entries = preview;
    if (errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            errorMessage!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      );
    }
    if (entries == null || entries.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          entries == null
              ? chart.description ?? '暂无榜单曲目'
              : chart.kind == 'family'
              ? '在 HMusic 听几首歌，这里就会有你的常听记录。'
              : chart.kind == 'spotify-personal'
              ? 'Spotify 暂无这个时段的收听记录。'
              : '暂无榜单曲目',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: palette.muted, height: 1.5),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entry in entries.take(3))
          ChartPreviewSong(entry: entry, onTap: () => onPlayEntry(entry)),
      ],
    );
  }
}
