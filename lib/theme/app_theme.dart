// EmoSphere visual language — dark premium theme (SPEC v0.3).
//
// Every screen builds on these tokens:
//   * [AppTheme.accent]             — indigo accent (#6366F1)
//   * [AppTheme.backgroundGradient] — #0B1020 → #0E1430 (const, usable in
//                                     `const BoxDecoration`)
//   * [AppTheme.glassDecoration] / [GlassCard] — frosted-glass cards with a
//                                     hairline border and soft shadow
//   * [AppTheme.dark]               — the MaterialApp [ThemeData]
//
// The eight emotion colours live in [Emotion] (single source of truth);
// [AppTheme.emotionColors] exposes them in the canonical order for legends.

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/models/emotion.dart';

/// Visual tokens and helpers of the EmoSphere dark theme.
class AppTheme {
  AppTheme._();

  /// Primary accent — SPEC indigo `#6366F1`.
  static const Color accent = Color(0xFF6366F1);

  /// Top colour of the app background gradient (`#0B1020`).
  static const Color backgroundTop = Color(0xFF0B1020);

  /// Bottom colour of the app background gradient (`#0E1430`).
  static const Color backgroundBottom = Color(0xFF0E1430);

  /// Glass card surface (applied with an alpha, see [glassDecoration]).
  static const Color surface = Color(0xFF141A31);

  /// Darker surface — bottom navigation bar, sheets, dialogs.
  static const Color surfaceHigh = Color(0xFF11162C);

  /// Hairline border of glass surfaces — white at 8 %.
  static const Color border = Color(0x14FFFFFF);

  /// Fill of input fields — white at 6 %.
  static const Color fieldFill = Color(0x0FFFFFFF);

  /// Screen background gradient (`#0B1020` → `#0E1430`).
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[backgroundTop, backgroundBottom],
  );

  /// The eight emotion colours in canonical [Emotion] order (map legend).
  static List<Color> get emotionColors => <Color>[
    for (final emotion in Emotion.values) emotion.color,
  ];

  /// Soft glow shadow in [color] (selected emotion tiles, FAB, heat cells).
  static List<BoxShadow> glow(
    Color color, {
    double opacity = 0.35,
    double blur = 18,
    double spread = 1,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: opacity),
        blurRadius: blur,
        spreadRadius: spread,
      ),
    ];
  }

  /// Frosted-glass card decoration.
  ///
  /// Use together with [GlassCard] (which adds the blur) or directly on a
  /// [Container] when no backdrop blur is required.
  static BoxDecoration glassDecoration({
    double radius = 20,
    Color? tint,
    double opacity = 0.55,
    Color? glowColor,
    double glowBlur = 24,
  }) {
    return BoxDecoration(
      color: (tint ?? surface).withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
        if (glowColor != null)
          BoxShadow(
            color: glowColor.withValues(alpha: 0.28),
            blurRadius: glowBlur,
            spreadRadius: 1,
          ),
      ],
    );
  }

  /// Material theme of the app: dark, transparent scaffold (screens paint the
  /// gradient background themselves) and indigo accents.
  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: Brightness.dark,
    ).copyWith(primary: accent, surface: surface);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent,
      splashColor: accent.withValues(alpha: 0.12),
      highlightColor: accent.withValues(alpha: 0.06),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        inactiveTrackColor: Colors.white.withValues(alpha: 0.14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent.withValues(alpha: 0.7)),
        ),
      ),
      dividerColor: Colors.white.withValues(alpha: 0.08),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
    );
  }
}

/// A frosted-glass card: blurred surface + hairline border + soft shadow.
///
/// The blur is applied with [ImageFilter.blur] over whatever is painted
/// behind the card (the screen gradient, map tiles, …).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.opacity = 0.55,
    this.tint,
    this.glowColor,
    this.onTap,
  });

  /// Card content.
  final Widget child;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Corner radius (must match [AppTheme.glassDecoration]).
  final double radius;

  /// Surface alpha (0 = fully transparent, 1 = solid [AppTheme.surface]).
  final double opacity;

  /// Optional surface tint; defaults to [AppTheme.surface].
  final Color? tint;

  /// Optional emotion-coloured glow behind the card.
  final Color? glowColor;

  /// Optional tap handler.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: AppTheme.glassDecoration(
            radius: radius,
            tint: tint,
            opacity: opacity,
            glowColor: glowColor,
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      card = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: card,
      );
    }
    return card;
  }
}
