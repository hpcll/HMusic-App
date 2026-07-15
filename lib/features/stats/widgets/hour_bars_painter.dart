import 'package:flutter/material.dart';

import '../models/stats.dart';

// 听歌时段 24 柱状，对齐 web .hour-bar：中性灰 0.85，峰值柱最深墨（.peak）。
class HourBarsPainter extends CustomPainter {
  const HourBarsPainter({
    required this.hours,
    required this.bar,
    required this.peak,
  });

  final List<HourPoint> hours;
  final Color bar;
  final Color peak;

  static const double _padY = 12;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    if (hours.isEmpty) return;
    final count = hours.length;
    final maxCount = hours.fold<int>(1, (m, p) => p.count > m ? p.count : m);
    final barW = (size.width - _gap * (count - 1)) / count;
    final barPaint = Paint()..color = bar.withValues(alpha: 0.85);
    final peakPaint = Paint()..color = peak;

    for (var i = 0; i < count; i++) {
      final bh = (hours[i].count / maxCount) * (size.height - _padY);
      final x = i * (barW + _gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - bh, barW, bh),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, hours[i].count == maxCount ? peakPaint : barPaint);
    }
  }

  @override
  bool shouldRepaint(HourBarsPainter oldDelegate) =>
      oldDelegate.hours != hours ||
      oldDelegate.bar != bar ||
      oldDelegate.peak != peak;
}
