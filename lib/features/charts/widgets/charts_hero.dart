import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../models/chart.dart';

// 窄屏主推轮播，结构借鉴 Apple Music「广播」页 Hero：横滑大卡 + 两侧露边（peek）暗示可滑动。
// 窄屏卡横比接近方图，1:1 封面全幅铺底裁切损失小；桌面宽屏不用本组件
// （横条会把方图拉糊），改用 charts_featured_lead 的头条卡形态。
// 视觉守 HMusic 纪律：底部墨色 scrim 兜底白字对比，青绿不出现在此处。
class ChartsHeroCarousel extends StatefulWidget {
  const ChartsHeroCarousel({
    required this.featured,
    required this.covers,
    required this.labelOf,
    required this.onOpen,
    super.key,
  });

  // 主推榜单（每来源取旗舰一张）。
  final List<Chart> featured;

  // chartId → #1 封面 url（缺则走深色占位）。
  final Map<String, String?> covers;

  // kind → 中文来源名。
  final String Function(String kind) labelOf;
  final void Function(Chart chart) onOpen;

  @override
  State<ChartsHeroCarousel> createState() => _ChartsHeroCarouselState();
}

class _ChartsHeroCarouselState extends State<ChartsHeroCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // viewportFraction < 1 → 当前卡居中，两侧露出邻卡边缘（peek）。
    _controller = PageController(viewportFraction: 0.86);
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    final page = _controller.page?.round() ?? 0;
    if (page != _page) setState(() => _page = page);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.featured.length,
            itemBuilder: (context, i) {
              final chart = widget.featured[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _HeroCard(
                  chart: chart,
                  cover: widget.covers[chart.id],
                  sourceLabel: widget.labelOf(chart.kind),
                  onTap: () => widget.onOpen(chart),
                ),
              );
            },
          ),
        ),
        if (widget.featured.length > 1) ...<Widget>[
          const SizedBox(height: 12),
          _Dots(count: widget.featured.length, active: _page),
        ],
      ],
    );
  }
}

// 单张主推大卡：深色媒体底 + scrim + 底部左对齐（来源小字 + 衬线榜名白字）。
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
    final radius = BorderRadius.circular(14);
    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: const Color(0xFF2A2A2E), // 深色媒体底：图未到/失败时白字仍可读。
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _cover(),
              // 底部墨色 scrim：托住白字对比（补 Apple 原版短板）。
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      sourceLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chart.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'NotoSerifSC',
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    final url = cover;
    if (url == null || url.isEmpty) return _placeholder;
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _placeholder,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder,
    );
  }

  Widget get _placeholder => const ColoredBox(
    color: Color(0xFF2A2A2E),
    child: Center(
      child: Icon(Icons.equalizer_rounded, size: 34, color: Colors.white24),
    ),
  );
}

// 分页圆点，墨色纪律：当前 text-strong、其余 line，不用青绿。
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count;
  final int active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        for (int i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == active ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == active ? palette.textStrong : palette.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ],
    );
  }
}
