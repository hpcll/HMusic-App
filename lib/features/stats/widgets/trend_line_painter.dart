import 'package:flutter/material.dart';

import '../models/stats.dart';

// 听歌趋势折线 + 8% 面积填充，对齐 web .trend-line/.trend-area（纯墨色）。
class TrendLinePainter extends CustomPainter {
  const TrendLinePainter({required this.points, required this.ink});

  final List<TrendPoint> points;
  final Color ink;

  static const double _padX = 8;
  static const double _padY = 16;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final n = points.length;
    final maxCount = points.fold<int>(1, (m, p) => p.count > m ? p.count : m);
    final stepX = n > 1 ? (size.width - _padX * 2) / (n - 1) : 0.0;
    double x(int i) => _padX + i * stepX;
    double y(int v) =>
        size.height - _padY - (v / maxCount) * (size.height - _padY * 2);

    final line = Path();
    for (var i = 0; i < n; i++) {
      final px = x(i);
      final py = y(points[i].count);
      if (i == 0) {
        line.moveTo(px, py);
      } else {
        line.lineTo(px, py);
      }
    }

    // 面积：折线收口到基线。
    final area = Path.from(line)
      ..lineTo(x(n - 1), size.height - _padY)
      ..lineTo(x(0), size.height - _padY)
      ..close();
    canvas.drawPath(area, Paint()..color = ink.withValues(alpha: 0.08));

    canvas.drawPath(
      line,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(TrendLinePainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.ink != ink;
}
