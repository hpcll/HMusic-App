import 'package:flutter/material.dart';

import 'hmusic_palette.dart';
import 'hmusic_radii.dart';

// 墨色刊物风主题:直接映射 docs/03 设计 token,不用 fromSeed——
// 种子色会把品牌青绿铺满全站组件,违反「青绿只表达正在发生的事」铁律。
// 主操作一律墨黑(暗色下转象牙白),青绿只由业务代码显式取 palette.accent。
abstract final class HMusicTheme {
  static const String serifFamily = 'NotoSerifSC';

  static ThemeData light() => _build(Brightness.light, HMusicPalette.light);

  static ThemeData dark() => _build(Brightness.dark, HMusicPalette.dark);

  static ThemeData _build(Brightness brightness, HMusicPalette p) {
    final ink = brightness == Brightness.light
        ? p.textStrong
        : const Color(0xFFE6E6E9);
    final onInk = brightness == Brightness.light
        ? p.background
        : const Color(0xFF131315);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: ink,
      onPrimary: onInk,
      secondary: p.accent,
      onSecondary: Colors.white,
      surface: p.panel,
      onSurface: p.text,
      surfaceContainerHighest: p.panelSecondary,
      onSurfaceVariant: p.muted,
      outline: p.line,
      outlineVariant: p.line,
      error: p.danger,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      splashFactory: InkSparkle.splashFactory,
      fontFamilyFallback: const <String>[
        'Inter',
        'PingFang SC',
        'Hiragino Sans GB',
        'Microsoft YaHei',
      ],
      extensions: <ThemeExtension<dynamic>>[p],
    );

    final sans = base.textTheme.apply(
      bodyColor: p.text,
      displayColor: p.textStrong,
    );
    // 衬线只给展示层(字标/页面大标题/播放页曲名),正文保持无衬线。
    TextStyle serif(TextStyle style, double size, [FontWeight? w]) =>
        style.copyWith(
          fontFamily: serifFamily,
          fontSize: size,
          fontWeight: w ?? FontWeight.w600,
          color: p.textStrong,
          height: 1.25,
        );
    final textTheme = sans.copyWith(
      displayLarge: serif(sans.displayLarge!, 44),
      displayMedium: serif(sans.displayMedium!, 36),
      displaySmall: serif(sans.displaySmall!, 30),
      headlineLarge: serif(sans.headlineLarge!, 28),
      headlineMedium: serif(sans.headlineMedium!, 24),
      headlineSmall: serif(sans.headlineSmall!, 21),
      titleLarge: sans.titleLarge!.copyWith(
        fontWeight: FontWeight.w600,
        color: p.textStrong,
      ),
    );

    final hairline = BorderSide(color: p.line);
    // 输入框走「灰底无描边大圆角」的软胶囊观感（对齐系统级登录表单）：
    // 描边款的线稿感是「硬」的主要来源，全站表单一并柔化；焦点可见性由
    // 光标承担（与搜索框同纪律），不加 focus 描边。
    const inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(HMusicRadii.input)),
      borderSide: BorderSide.none,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: p.textStrong,
        titleTextStyle: sans.titleMedium?.copyWith(color: p.muted),
        iconTheme: IconThemeData(color: p.textStrong, size: 22),
      ),
      cardTheme: CardThemeData(
        color: p.panel,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HMusicRadii.card),
          side: hairline,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: onInk,
          // 只约束最小高度。千万不能用 Size.fromHeight——它的宽是 infinity，
          // 按钮一旦放进 Row/Wrap 等不限宽父级就 RenderBox not laid out。
          // 整行大按钮由调用处的 stretch Column 或局部 styleFrom 负责。
          minimumSize: const Size(64, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
          // 按钮族统一胶囊：与 dock/mini/搜索框的胶囊 chrome 同一语言，
          // 也是「柔化直角」的主抓手（参考系统级登录页的主按钮形态）。
          shape: const StadiumBorder(),
          textStyle: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          side: hairline,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.mutedStrong,
          textStyle: const TextStyle(fontSize: 13.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.panelSecondary,
        hintStyle: TextStyle(color: p.muted, fontSize: 14),
        labelStyle: TextStyle(color: p.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ink,
        inactiveTrackColor: p.line,
        thumbColor: ink,
        overlayColor: ink.withValues(alpha: 0.08),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: p.panel,
        selectedColor: ink,
        checkmarkColor: onInk,
        labelStyle: TextStyle(color: p.text, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: onInk, fontSize: 13),
        side: hairline,
        shape: const StadiumBorder(),
        showCheckmark: false,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: ink),
      dividerTheme: DividerThemeData(color: p.lineSoft, thickness: 1),
      iconTheme: IconThemeData(color: p.textStrong),
      listTileTheme: ListTileThemeData(
        iconColor: p.mutedStrong,
        textColor: p.text,
      ),
      // docs/03 模态卡：panel 底 / hairline，表单主体保持不透明；圆角随全站
      // 柔化取 card token；遮罩的 blur(2px) 由 showHMusicDialog 负责。
      dialogTheme: DialogThemeData(
        backgroundColor: p.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HMusicRadii.card),
          side: hairline,
        ),
      ),
      // 轻量提示不用 SnackBar：全站统一走 showHMusicToast（docs/03 Toast 规格）。
    );
  }
}
