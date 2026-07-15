import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/stats.dart';

// 来源平台环形图，对齐 web renderSources：底环 line-soft，占比段从顶部（-90°）顺时针铺。
// 纯墨色版：占比最大段（index 0，已降序）最深墨，其余中性灰阶（下限 0.45）。
class SourceDonutPainter extends CustomPainter {
  const SourceDonutPainter({
    required this.slices,
    required this.ink,
    required this.muted,
    required this.baseRing,
  });

  final List<SourceSlice> slices;
  final Color ink;
  final Color muted;
  final Color baseRing;

  static const List<double> _grayAlpha = <double>[1, 0.9, 0.65, 0.45];
  static const double _strokeWidth = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - _strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = baseRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth,
    );

    var start = -math.pi / 2;
    for (var i = 0; i < slices.length; i++) {
      final sweep = (slices[i].percent / 100) * 2 * math.pi;
      if (sweep <= 0) continue;
      final color = i == 0 ? ink : muted;
      final alpha = i == 0
          ? 1.0
          : _grayAlpha[math.min(i, _grayAlpha.length - 1)];
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(SourceDonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.ink != ink ||
      oldDelegate.muted != muted;
}

// 图例点色/透明度：与环形段一致（供图例复用）。
({Color color, double alpha}) sourceLegendStyle(
  int index,
  Color ink,
  Color muted,
) {
  if (index == 0) return (color: ink, alpha: 1);
  const grayAlpha = <double>[1, 0.9, 0.65, 0.45];
  return (
    color: muted,
    alpha: grayAlpha[math.min(index, grayAlpha.length - 1)],
  );
}
