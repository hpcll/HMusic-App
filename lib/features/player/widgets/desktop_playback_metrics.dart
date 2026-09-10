import 'dart:math' as math;

import 'package:flutter/painting.dart';

enum DesktopPlaybackLayout { wide, compact, stacked }

// 组件和外壳共用完整包络，包含上下外边距和内边距，不另叠魔法数字。
class DesktopPlaybackMetrics {
  DesktopPlaybackMetrics({
    required double contentWidth,
    required TextScaler textScaler,
  }) : layout = contentWidth < 760 || textScaler.scale(14) > 19.6
           ? DesktopPlaybackLayout.stacked
           : contentWidth >= 1040
           ? DesktopPlaybackLayout.wide
           : DesktopPlaybackLayout.compact,
       metadataHeight = math.max(
         44,
         ((textScaler.scale(14) + textScaler.scale(12)) * 1.25 + 4)
             .ceilToDouble(),
       );

  final DesktopPlaybackLayout layout;
  final double metadataHeight;

  double get height =>
      24 +
      switch (layout) {
        DesktopPlaybackLayout.wide => math.max(metadataHeight, 92),
        DesktopPlaybackLayout.compact => metadataHeight + 8 + 44,
        DesktopPlaybackLayout.stacked => metadataHeight + 8 + 44 + 8 + 44,
      };
}

double desktopPlaybackBarHeight({
  required double contentWidth,
  required TextScaler textScaler,
}) => DesktopPlaybackMetrics(
  contentWidth: contentWidth,
  textScaler: textScaler,
).height;
