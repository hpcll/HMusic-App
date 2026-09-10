import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';
import '../../../shared/widgets/hmusic_cover.dart';
import '../models/chart.dart';

// 手机主推：方封面与文字并列，右侧露边提示横滑，不把方图裁成横幅。
class ChartsHeroCarousel extends StatefulWidget {
  const ChartsHeroCarousel({
    required this.featured,
    required this.covers,
    required this.labelOf,
    required this.onOpen,
    super.key,
  });

  final List<Chart> featured;
  final Map<String, String?> covers;
  final String Function(String kind) labelOf;
  final void Function(Chart chart) onOpen;

  @override
  State<ChartsHeroCarousel> createState() => _ChartsHeroCarouselState();
}

class _ChartsHeroCarouselState extends State<ChartsHeroCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final height =
        32 +
        math.max(104, scaler.scale(12) * 1.4 + 6 + scaler.scale(20) * 1.3 * 2);
    return SizedBox(
      height: height.ceilToDouble(),
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: widget.featured.length,
        itemBuilder: (context, index) {
          final chart = widget.featured[index];
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: index == widget.featured.length - 1 ? 16 : 0,
            ),
            child: _HeroCard(
              chart: chart,
              cover: widget.covers[chart.id],
              sourceLabel: widget.labelOf(chart.kind),
              onTap: () => widget.onOpen(chart),
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.chart,
    required this.cover,
    required this.sourceLabel,
    required this.onTap,
  });

  final Chart chart;
  final String? cover;
  final String sourceLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return HMusicCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Row(
        children: <Widget>[
          HMusicCover(url: cover, size: 92, radius: 10, iconSize: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  sourceLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: palette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  chart.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'NotoSerifSC',
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                    color: palette.textStrong,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
