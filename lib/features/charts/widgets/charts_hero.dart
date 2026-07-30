import 'package:flutter/material.dart';

import '../../../shared/widgets/pressable_scale.dart';
import '../models/chart.dart';

// 窄屏主推轮播，结构借鉴 Apple Music「广播」页 Hero：横滑大卡左对齐页面 16 基线
//（与页头、分组卡带同列），右侧露出邻卡边缘（peek）暗示可滑动——peek 已完整表达
// 可滑性，不再加分页圆点（Apple Music 同款：横滑架无 dots，省掉纵向节奏杂点）。
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
  // viewportFraction < 1 + padEnds false → 当前卡左对齐，右侧露出邻卡边缘（peek）。
  late final PageController _controller = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190,
      child: PageView.builder(
        controller: _controller,
        // padEnds false：卡片贴页面左基线而非居中，修掉与下方卡带的错位。
        padEnds: false,
        itemCount: widget.featured.length,
        itemBuilder: (context, i) {
          final chart = widget.featured[i];
          return Padding(
            // 左 16 对齐全页基线并兼作卡间距；末卡补右 16，滑到底时贴回栅格。
            padding: EdgeInsets.only(
              left: 16,
              right: i == widget.featured.length - 1 ? 16 : 0,
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
    return PressableScale(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 深色媒体底常驻最底层：图未到/失败时白字仍可读，封面淡入时无白闪。
            _placeholder,
            _cover(context),
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
    );
  }

  Widget _cover(BuildContext context) {
    final url = cover;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Image.network(
      url,
      fit: BoxFit.cover,
      // 卡宽 ≈ 0.9 屏宽，按整屏宽解码作上限，避免原图全尺寸解码掉帧。
      cacheWidth:
          (MediaQuery.sizeOf(context).width *
                  MediaQuery.devicePixelRatioOf(context))
              .round(),
      // 首帧就绪后 200ms 淡入盖住深色占位，替代到图瞬间硬切；同步缓存命中直显。
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        );
      },
      // 失败露出底层深色占位。
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  Widget get _placeholder => const ColoredBox(
    color: Color(0xFF2A2A2E),
    child: Center(
      child: Icon(Icons.equalizer_rounded, size: 34, color: Colors.white24),
    ),
  );
}
