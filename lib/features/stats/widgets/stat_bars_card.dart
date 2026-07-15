import 'package:flutter/material.dart';

import '../../../app/theme/hmusic_palette.dart';
import '../../../shared/widgets/hmusic_card.dart';

// 横向占比条卡片，对齐 web .stat-bars（艺术家/专辑复用）：名称 + 轨道 + 数值，首位最深墨。
class StatBarsCard extends StatelessWidget {
  const StatBarsCard({required this.title, required this.rows, super.key});

  final String title;
  final List<({String name, int value})> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    if (rows.isEmpty) return const SizedBox.shrink();
    final maxValue = rows.fold<int>(1, (m, r) => r.value > m ? r.value : m);

    return HMusicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: palette.textStrong,
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < rows.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 10),
              child: _BarRow(
                name: rows[i].name,
                value: rows[i].value,
                fraction: rows[i].value / maxValue,
                lead: i == 0,
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.name,
    required this.value,
    required this.fraction,
    required this.lead,
  });

  final String name;
  final int value;
  final double fraction;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 96,
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: palette.textStrong),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Container(
              height: 10,
              color: palette.panelSecondary,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: lead
                        ? palette.textStrong
                        : palette.mutedStrong.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: palette.mutedStrong),
          ),
        ),
      ],
    );
  }
}
