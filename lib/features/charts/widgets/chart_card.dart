import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../models/chart.dart';

// 榜单卡片，对齐 web .chart-card：卡头(#1 封面 + 衬线榜名) + Top3 可点播预览 + 「查看全部 ›」。
// preview: null 且 pending=true → 加载中；null 且 pending=false → 回退描述；非空 → Top3 行。
class ChartCard extends StatelessWidget {
  const ChartCard({
    required this.chart,
    required this.preview,
    required this.pending,
    required this.onOpen,
    required this.onPlayEntry,
    super.key,
  });

  final Chart chart;
  final List<ChartEntry>? preview;
  final bool pending;
  final VoidCallback onOpen;
  final void Function(ChartEntry entry) onPlayEntry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final cover = (preview != null && preview!.isNotEmpty)
        ? preview!.first.coverUrl
        : null;

    return HMusicCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              HMusicCover(url: cover, size: 44, radius: 7, iconSize: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chart.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: palette.textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 固定预览区高度：Top3 不足 3 首或走描述回退时卡片仍等高，网格对齐（对齐 web min-height）。
          // 78 = 3 行 × (文本行高 + 6 竖向内距) 的包络，Android 字体度量比桌面高零点几像素，
          // 76 会精确溢出 0.563px（黄黑警告条），留 2px 余量。
          SizedBox(height: 78, child: _preview(context)),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '查看全部 ›',
              style: TextStyle(fontSize: 12, color: palette.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _preview(BuildContext context) {
    final palette = context.palette;
    if (pending && preview == null) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(
          '加载中…',
          style: TextStyle(fontSize: 12, color: palette.muted),
        ),
      );
    }
    final entries = preview;
    if (entries == null || entries.isEmpty) {
      return Text(
        chart.description ?? '',
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: palette.muted, height: 1.5),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final entry in entries)
          _PreviewSong(entry: entry, onTap: () => onPlayEntry(entry)),
      ],
    );
  }
}

// 卡片内预览行：序号 + 歌名 + 歌手，点击直接点播（不冒泡进详情）。
class _PreviewSong extends StatelessWidget {
  const _PreviewSong({required this.entry, required this.onTap});

  final ChartEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            SizedBox(
              width: 13,
              child: Text(
                '${entry.rank}',
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: palette.text),
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                entry.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: palette.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
