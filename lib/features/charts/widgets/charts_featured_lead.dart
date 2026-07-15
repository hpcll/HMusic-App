import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/chart.dart';

// 桌面主打横滑带的单卡：白 panel 细边卡，左侧 1:1 封面原比例内嵌，
// 右侧来源眉题 + 衬线榜名 + Top3 预览。横滑 + 露边的骨架对齐 Apple Music
// 「广播」页 Hero；卡内不走 Apple 的全幅铺图——它的素材是专制横版图，
// 我们的素材是方形封面，硬撑 banner 必然裁糊，深色大块也违反内容层暖纸纪律。
// 窄屏仍用全幅轮播（charts_hero）。
class ChartsFeaturedLead extends StatelessWidget {
  const ChartsFeaturedLead({
    required this.chart,
    required this.entries,
    required this.sourceLabel,
    required this.onOpen,
    super.key,
  });

  // 横滑带里的统一卡宽；高 = 封面 _coverSize + 上下 padding 16×2。
  static const double width = 460;
  static const double height = 182;
  static const double _coverSize = 150;

  final Chart chart;

  // Top3 预览；加载中/失败为空列表，降级为描述行。
  final List<ChartEntry> entries;

  final String sourceLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: _coverSize,
                  height: _coverSize,
                  child: _cover(context, palette),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(child: _info(palette)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(HMusicPalette palette) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '$sourceLabel · 每日更新',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1,
            color: palette.mutedStrong,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          chart.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'NotoSerifSC',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: palette.textStrong,
          ),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(
            chart.description ?? '每日更新的热门榜单',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: palette.muted),
          )
        else
          for (final entry in entries.take(3)) _entryRow(entry, palette),
      ],
    );
  }

  Widget _entryRow(ChartEntry entry, HMusicPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 20,
            child: Text(
              '${entry.rank}',
              style: TextStyle(
                fontFamily: 'NotoSerifSC',
                fontSize: 13,
                color: palette.muted,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: entry.title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: palette.text,
                    ),
                  ),
                  TextSpan(
                    text: ' · ${entry.artist}',
                    style: TextStyle(fontSize: 13, color: palette.muted),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cover(BuildContext context, HMusicPalette palette) {
    final url = entries.isNotEmpty ? entries.first.coverUrl : null;
    if (url == null || url.isEmpty) return _placeholder(palette);
    return Image.network(
      url,
      fit: BoxFit.cover,
      // 按展示尺寸解码，避免原图全尺寸解码拖垮滚动帧率（见 hmusic_cover）。
      cacheWidth: (_coverSize * MediaQuery.devicePixelRatioOf(context)).round(),
      errorBuilder: (_, _, _) => _placeholder(palette),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(palette),
    );
  }

  // 占位走暖纸系（panel-2 底 + muted 图标），不再用深色媒体底——桌面卡是内容层。
  Widget _placeholder(HMusicPalette palette) => ColoredBox(
    color: palette.panelSecondary,
    child: Center(
      child: Icon(Icons.equalizer_rounded, size: 34, color: palette.muted),
    ),
  );
}
