import 'dart:ui';

import 'package:flutter/material.dart';

enum GlassQuality { high, medium, off }

class AdaptiveGlassSurface extends StatelessWidget {
  const AdaptiveGlassSurface({
    required this.child,
    this.quality = GlassQuality.medium,
    this.padding = const EdgeInsets.all(12),
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    super.key,
  });

  final Widget child;
  final GlassQuality quality;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tint = dark ? const Color(0x941C1C1E) : const Color(0x9EFFFFFF);
    final sigma = switch (quality) {
      GlassQuality.high => 28.0,
      GlassQuality.medium => 18.0,
      GlassQuality.off => 0.0,
    };
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: quality == GlassQuality.off
            ? Theme.of(context).colorScheme.surface
            : tint,
        borderRadius: borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: dark ? 0.12 : 0.45),
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 28,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    if (sigma == 0) return surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: surface,
      ),
    );
  }
}
