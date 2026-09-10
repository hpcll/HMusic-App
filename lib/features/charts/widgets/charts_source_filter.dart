import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../models/chart.dart';
import '../models/chart_catalog.dart';

class ChartsSourceFilter extends StatelessWidget {
  const ChartsSourceFilter({
    required this.charts,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final List<Chart> charts;
  final String selected;
  final ValueChanged<String> onSelected;

  void _select(BuildContext chipContext, String kind) {
    onSelected(kind);
    final target = chipContext.findRenderObject();
    if (target == null) return;
    // 只移动标签行；选中项靠近中间时，右侧下一项自然露出，首尾由滚动范围限位。
    unawaited(
      Scrollable.of(chipContext).position.ensureVisible(
        target,
        alignment: 0.5,
        duration: MediaQuery.disableAnimationsOf(chipContext)
            ? Duration.zero
            : const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sources = chartSources.where(
      (source) =>
          source.$1 == 'featured' ||
          charts.any((chart) => chart.kind == source.$1),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '发现榜单',
            style: TextStyle(
              fontFamily: 'NotoSerifSC',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: palette.textStrong,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            spacing: 8,
            children: <Widget>[
              for (final (kind, label) in sources)
                Builder(
                  key: ValueKey(kind),
                  builder: (chipContext) => Semantics(
                    button: true,
                    selected: selected == kind,
                    child: PressableScale(
                      onTap: () => _select(chipContext, kind),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: selected == kind
                              ? palette.textStrong
                              : palette.panelSecondary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: selected == kind
                                ? palette.background
                                : palette.mutedStrong,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
