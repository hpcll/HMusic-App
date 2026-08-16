import 'package:flutter/material.dart';

@immutable
class HMusicPalette extends ThemeExtension<HMusicPalette> {
  const HMusicPalette({
    required this.background,
    required this.panel,
    required this.panelSecondary,
    required this.text,
    required this.textStrong,
    required this.muted,
    required this.mutedStrong,
    required this.line,
    required this.lineSoft,
    required this.accent,
    required this.danger,
  });

  static const HMusicPalette light = HMusicPalette(
    background: Color(0xFFF7F7F8),
    panel: Color(0xFFFFFFFF),
    panelSecondary: Color(0xFFF0F0F1),
    text: Color(0xFF333333),
    textStrong: Color(0xFF1A1A1A),
    // muted 在 #F7F7F8 底上需 ≥4.2:1（原 #999 只有 2.8，副标题/时间戳不达标）。
    muted: Color(0xFF767676),
    mutedStrong: Color(0xFF5F5F5F),
    line: Color(0xFFE3E3E5),
    lineSoft: Color(0xFFECECEE),
    accent: Color(0xFF21B0A5),
    danger: Color(0xFFB91C1C),
  );

  static const HMusicPalette dark = HMusicPalette(
    background: Color(0xFF131315),
    panel: Color(0xFF1B1B1E),
    panelSecondary: Color(0xFF232326),
    text: Color(0xFFD6D6D8),
    textStrong: Color(0xFFF0F0F2),
    muted: Color(0xFF85858A),
    mutedStrong: Color(0xFFA3A3A8),
    line: Color(0xFF313135),
    lineSoft: Color(0xFF29292D),
    accent: Color(0xFF2EC4B8),
    danger: Color(0xFFEF4444),
  );

  final Color background;
  final Color panel;
  final Color panelSecondary;
  final Color text;
  final Color textStrong;
  final Color muted;
  final Color mutedStrong;
  final Color line;
  final Color lineSoft;
  final Color accent;
  final Color danger;

  @override
  HMusicPalette copyWith({
    Color? background,
    Color? panel,
    Color? panelSecondary,
    Color? text,
    Color? textStrong,
    Color? muted,
    Color? mutedStrong,
    Color? line,
    Color? lineSoft,
    Color? accent,
    Color? danger,
  }) {
    return HMusicPalette(
      background: background ?? this.background,
      panel: panel ?? this.panel,
      panelSecondary: panelSecondary ?? this.panelSecondary,
      text: text ?? this.text,
      textStrong: textStrong ?? this.textStrong,
      muted: muted ?? this.muted,
      mutedStrong: mutedStrong ?? this.mutedStrong,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      accent: accent ?? this.accent,
      danger: danger ?? this.danger,
    );
  }

  @override
  HMusicPalette lerp(covariant HMusicPalette? other, double t) {
    if (other == null) return this;
    return HMusicPalette(
      background: Color.lerp(background, other.background, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelSecondary: Color.lerp(panelSecondary, other.panelSecondary, t)!,
      text: Color.lerp(text, other.text, t)!,
      textStrong: Color.lerp(textStrong, other.textStrong, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedStrong: Color.lerp(mutedStrong, other.mutedStrong, t)!,
      line: Color.lerp(line, other.line, t)!,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

// 便捷读取:context.hmusicPalette / theme.extension 简写。
extension HMusicPaletteX on BuildContext {
  HMusicPalette get palette =>
      Theme.of(this).extension<HMusicPalette>() ?? HMusicPalette.light;
}
