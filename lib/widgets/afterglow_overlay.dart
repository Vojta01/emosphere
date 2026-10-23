// R10 + R11 — the after-send "afterglow".
//
// A ~4.4 s full-screen emotion-matched particle animation that ends with a
// reflective quote card (one of 20 per emotion). Opened as a transparent
// route right after a successful check-in.
//
// Interaction: tap once while the particles play to skip ahead to the quote,
// tap again (or press back) to close. Reduced-motion users jump straight to
// the quote. Haptics are optional (`AppState.afterglowHaptics`).

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/strings.dart';
import '../core/models/emotion.dart';
import '../core/quotes/quotes.dart';
import '../theme/app_theme.dart';
import 'quote_card.dart';

/// Opens the afterglow over the whole app; resolves when it is dismissed.
Future<void> showAfterglow(
  BuildContext context, {
  required Strings s,
  required Emotion emotion,
  required int intensity,
  required Quote quote,
  required bool haptics,
}) {
  return Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => AfterglowOverlay(
        s: s,
        emotion: emotion,
        intensity: intensity,
        quote: quote,
        haptics: haptics,
      ),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen particle animation + quote card shown after sending.
class AfterglowOverlay extends StatefulWidget {
  const AfterglowOverlay({
    super.key,
    required this.s,
    required this.emotion,
    required this.intensity,
    required this.quote,
    required this.haptics,
  });

  /// Localized strings of the current UI language.
  final Strings s;

  /// The emotion the user just sent (drives colours and the particles).
  final Emotion emotion;

  /// The intensity the user just sent (kept for the record / future use).
  final int intensity;

  /// The quote revealed at the end of the animation.
  final Quote quote;

  /// Whether the animation plays haptic feedback.
  final bool haptics;

  @override
  State<AfterglowOverlay> createState() => _AfterglowOverlayState();
}

class _AfterglowOverlayState extends State<AfterglowOverlay>
    with SingleTickerProviderStateMixin {
  /// Total run: ~3.4 s of particles, quote fades in around 2.9–3.8 s.
  static const Duration _duration = Duration(milliseconds: 4400);

  /// Timeline window in which the quote card fades in.
  static const double _quoteStart = 0.66;
  static const double _quoteEnd = 0.86;

  /// Timeline window in which the particles play.
  static const double _particleEnd = 0.78;

  /// Soft haptic pulses at these fractions of the timeline.
  static const List<double> _pulseAt = <double>[0.18, 0.36, 0.54, 0.66];

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _duration)..forward();

  bool _reducedMotion = false;
  final Set<int> _pulsesDone = <int>{};

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTick);
    if (widget.haptics) {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      // Reduced motion: show the quote at once, no particle run.
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Fires the soft haptic texture as the timeline passes each mark.
  void _onTick() {
    if (!widget.haptics || _reducedMotion) return;
    final v = _controller.value;
    for (var i = 0; i < _pulseAt.length; i++) {
      if (v >= _pulseAt[i] && _pulsesDone.add(i)) {
        HapticFeedback.selectionClick();
      }
    }
  }

  void _handleTap() {
    if (_controller.value < _quoteStart) {
      // Skip ahead to the quote.
      if (widget.haptics) {
        HapticFeedback.lightImpact();
      }
      _controller.animateTo(
        1,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.emotion.color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // One quiet wash of the emotion colour over the app background.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.15,
                  colors: [
                    color.withValues(alpha: 0.20),
                    const Color(0xFF0B1020).withValues(alpha: 0.985),
                  ],
                  stops: const [0, 0.72],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _AfterglowPainter(
                  emotion: widget.emotion,
                  t: _interval(_controller.value, 0, _particleEnd),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    _orb(color),
                    const Spacer(flex: 2),
                    Flexible(
                      flex: 6,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _quoteCard(color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _hint(),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The big emotion emoji in a glowing ring; dims as the quote arrives.
  Widget _orb(Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final v = _controller.value;
        final appear = _interval(v, 0, 0.14);
        final dim = 1 - 0.62 * _interval(v, 0.45, _quoteEnd);
        final scale = 1 + 0.045 * math.sin(v * math.pi * 2.4);
        return Opacity(
          opacity: appear * dim,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        width: 148,
        height: 148,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.16),
          border: Border.all(color: color.withValues(alpha: 0.35)),
          boxShadow: AppTheme.glow(color, opacity: 0.5, blur: 60, spread: 2),
        ),
        child: Center(
          child: Text(
            widget.emotion.emoji,
            style: const TextStyle(fontSize: 62),
          ),
        ),
      ),
    );
  }

  /// The glass quote card that rises in at the end of the animation.
  Widget _quoteCard(Color color) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final q = Curves.easeOutCubic.transform(
          _interval(_controller.value, _quoteStart, _quoteEnd),
        );
        return Opacity(
          opacity: q,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - q)),
            child: child,
          ),
        );
      },
      child: QuoteCard(
        key: const Key('afterglow_quote'),
        s: widget.s,
        quote: widget.quote,
        color: color,
      ),
    );
  }

  /// "Tap anywhere to close" — appears together with the quote.
  Widget _hint() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _interval(_controller.value, _quoteStart + 0.06, _quoteEnd),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 14,
            color: Colors.white.withValues(alpha: 0.45),
          ),
          const SizedBox(width: 6),
          Text(
            widget.s.tr('afterglow.closeHint'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Linear 0..1 progress of [v] inside the [a]..[b] window.
double _interval(double v, double a, double b) {
  if (b <= a) return v >= b ? 1 : 0;
  return ((v - a) / (b - a)).clamp(0.0, 1.0);
}

/// Deterministic particle field — one visual per emotion.
///
/// All particles are pure functions of the timeline [t] and their index, so
/// the field needs no per-frame state and rebuilds identically every frame.
class _AfterglowPainter extends CustomPainter {
  _AfterglowPainter({required this.emotion, required this.t});

  /// Emotion whose particles to draw.
  final Emotion emotion;

  /// Particle timeline, 0..1 (clamped by the caller).
  final double t;

  /// Unit radial-gradient dot shader (white core → transparent edge); the
  /// per-dot colour is applied with a [ColorFilter] so exactly one shader
  /// is created for the whole run.
  static final Shader _dotShader = const RadialGradient(
    colors: [Colors.white, Color(0x00FFFFFF)],
  ).createShader(const Rect.fromLTWH(-1, -1, 2, 2));

  final Paint _dotPaint = Paint();

  /// Deterministic pseudo-random 0..1 for particle [i] with [salt].
  static double _hash(int i, int salt) {
    final v = math.sin(i * 12.9898 + salt * 78.233) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// A soft glowing dot of [radius] at [at].
  void _softDot(Canvas canvas, Offset at, double radius, Color color, double alpha) {
    if (alpha <= 0.012 || radius <= 0) return;
    _dotPaint
      ..shader = _dotShader
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: alpha.clamp(0.0, 1.0)),
        BlendMode.modulate,
      );
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.scale(radius);
    canvas.drawCircle(Offset.zero, 1, _dotPaint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    // Particles fade out as the quote takes over.
    final env = 1 - _interval(t, 0.82, 1.0);
    if (env <= 0) return;
    switch (emotion) {
      case Emotion.joy:
        _sparks(canvas, size, env);
      case Emotion.calm:
        _rings(canvas, size, env);
      case Emotion.love:
        _hearts(canvas, size, env);
      case Emotion.surprise:
        _burst(canvas, size, env);
      case Emotion.sadness:
        _drops(canvas, size, env);
      case Emotion.anger:
        _embers(canvas, size, env);
      case Emotion.fear:
        _smoke(canvas, size, env);
      case Emotion.tiredness:
        _motes(canvas, size, env);
    }
  }

  /// Joy: golden sparks rising with a twinkle.
  void _sparks(Canvas canvas, Size size, double env) {
    const count = 42;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 1) + t * (0.55 + _hash(i, 2) * 0.75)) % 1.0;
      final x =
          size.width * (0.08 + 0.84 * _hash(i, 3)) +
          math.sin((t * 6 + i) * 0.9) * 14;
      final y = size.height * (0.98 - life * 0.95);
      final r = 1.6 + _hash(i, 4) * 2.6;
      final twinkle = 0.55 + 0.45 * math.sin(life * math.pi * (4 + _hash(i, 5) * 4));
      final alpha = math.sin(life * math.pi) * 0.85 * twinkle * env;
      _softDot(canvas, Offset(x, y), r * 3.2, emotion.color, alpha * 0.5);
      _softDot(canvas, Offset(x, y), r, Colors.white, alpha * 0.75);
    }
  }

  /// Calm: slow rings expanding from the centre plus drifting motes.
  void _rings(Canvas canvas, Size size, double env) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.62;
    const ringCount = 4;
    for (var i = 0; i < ringCount; i++) {
      final p = (t * 1.15 - i * 0.18) % 1.0;
      final radius = maxR * Curves.easeOutCubic.transform(p);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = emotion.color.withValues(alpha: (1 - p) * 0.28 * env);
      canvas.drawCircle(center, radius, paint);
    }
    const motes = 14;
    for (var i = 0; i < motes; i++) {
      final life = (_hash(i, 11) + t * 0.28) % 1.0;
      final x =
          size.width * (0.1 + 0.8 * _hash(i, 12)) + math.sin(t * 2 + i) * 8;
      final y = size.height * (0.9 - life * 0.75);
      final alpha = math.sin(life * math.pi) * 0.35 * env;
      _softDot(canvas, Offset(x, y), 4.5, emotion.color, alpha);
    }
  }

  /// Love: hearts floating up with a gentle sway.
  void _hearts(Canvas canvas, Size size, double env) {
    const count = 16;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 21) + t * (0.4 + _hash(i, 22) * 0.35)) % 1.0;
      final x =
          size.width * (0.12 + 0.76 * _hash(i, 23)) +
          math.sin(life * math.pi * 2 + i) * 20;
      final y = size.height * (1.02 - life * 1.05);
      final s = 5.5 + _hash(i, 24) * 7.5;
      final alpha = math.sin(life * math.pi) * 0.8 * env;
      if (alpha <= 0.012) continue;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          emotion.color,
          Colors.white,
          _hash(i, 25) * 0.35,
        )!.withValues(alpha: alpha);
      canvas.drawPath(_heartPath(Offset(x, y), s), paint);
    }
  }

  /// A classic bezier heart centred at [c] with half-width [s].
  Path _heartPath(Offset c, double s) {
    final path = Path();
    path.moveTo(c.dx, c.dy + s * 0.9);
    path.cubicTo(
      c.dx - s * 1.3,
      c.dy - s * 0.1,
      c.dx - s * 0.55,
      c.dy - s * 1.05,
      c.dx,
      c.dy - s * 0.35,
    );
    path.cubicTo(
      c.dx + s * 0.55,
      c.dy - s * 1.05,
      c.dx + s * 1.3,
      c.dy - s * 0.1,
      c.dx,
      c.dy + s * 0.9,
    );
    return path;
  }

  /// Surprise: a bright burst from the centre.
  void _burst(Canvas canvas, Size size, double env) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide * 0.66;
    final flight = Curves.easeOutCubic.transform(_interval(t, 0, 0.55));
    final fade = 1 - _interval(t, 0.45, 0.85);
    const count = 54;
    for (var i = 0; i < count; i++) {
      final angle = _hash(i, 31) * math.pi * 2;
      final dist = maxR * (0.2 + 0.8 * _hash(i, 32)) * flight;
      final at = center + Offset(math.cos(angle), math.sin(angle)) * dist;
      final r = 1.3 + _hash(i, 33) * 2.2;
      final alpha = 0.85 * fade * env;
      _softDot(canvas, at, r * 2.6, emotion.color, alpha * 0.55);
      _softDot(canvas, at, r, Colors.white, alpha * 0.8);
    }
    final ringP = _interval(t, 0, 0.6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = emotion.color.withValues(
        alpha: (1 - ringP) * 0.35 * env,
      );
    canvas.drawCircle(
      center,
      maxR * 0.9 * Curves.easeOutCubic.transform(ringP),
      paint,
    );
  }

  /// Sadness: rain-like drops falling past.
  void _drops(Canvas canvas, Size size, double env) {
    const count = 30;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 41) + t * (0.45 + _hash(i, 42) * 0.4)) % 1.0;
      final x = size.width * (0.06 + 0.88 * _hash(i, 43)) + life * 12;
      final y = size.height * (-0.05 + life * 1.1);
      final len = 9 + _hash(i, 44) * 13;
      final alpha = math.sin(life * math.pi) * 0.65 * env;
      if (alpha <= 0.012) continue;
      final paint = Paint()
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = emotion.color.withValues(alpha: alpha);
      canvas.drawLine(Offset(x, y), Offset(x - 1.5, y + len), paint);
      canvas.drawCircle(
        Offset(x, y + len),
        1.4,
        Paint()..color = emotion.color.withValues(alpha: alpha),
      );
    }
  }

  /// Anger: embers rising with a hot flicker.
  void _embers(Canvas canvas, Size size, double env) {
    const count = 40;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 51) + t * (0.75 + _hash(i, 52) * 0.6)) % 1.0;
      final x =
          size.width * (0.1 + 0.8 * _hash(i, 53)) +
          math.sin(t * 14 + i * 2.3) * (6 + _hash(i, 54) * 10) * life;
      final y = size.height * (1.05 - life * 1.1);
      final flicker = 0.5 + 0.5 * math.sin(t * 47 + i * 3.1);
      final alpha = math.sin(life * math.pi) * flicker * 0.85 * env;
      if (alpha <= 0.012) continue;
      final r = 1.2 + _hash(i, 55) * 1.8;
      final hot = Color.lerp(
        const Color(0xFFFF7A2F),
        emotion.color,
        _hash(i, 56),
      )!;
      _softDot(canvas, Offset(x, y), r * 3.0, hot, alpha * 0.7);
      _softDot(canvas, Offset(x, y), r, const Color(0xFFFFD9B0), alpha * 0.8);
    }
  }

  /// Fear: large soft smoke drifts.
  void _smoke(Canvas canvas, Size size, double env) {
    const count = 14;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 61) + t * 0.22) % 1.0;
      final x =
          size.width * (0.05 + 0.9 * _hash(i, 62)) +
          math.sin(life * math.pi * 2 + i) * 30;
      final y = size.height * (0.95 - life * 0.85);
      final r = 36 + _hash(i, 63) * 58;
      final alpha = math.sin(life * math.pi) * 0.10 * env;
      _softDot(canvas, Offset(x, y), r, emotion.color, alpha);
    }
  }

  /// Tiredness: a slow breathing glow with sleepy motes.
  void _motes(Canvas canvas, Size size, double env) {
    final center = size.center(Offset.zero);
    final breathe = 1 + 0.07 * math.sin(t * math.pi * 2.2);
    _softDot(
      canvas,
      center,
      size.shortestSide * 0.55 * breathe,
      emotion.color,
      0.10 * env + 0.02,
    );
    const count = 22;
    for (var i = 0; i < count; i++) {
      final life = (_hash(i, 71) + t * 0.18) % 1.0;
      final x =
          size.width * (0.1 + 0.8 * _hash(i, 72)) + math.sin(t * 1.5 + i) * 10;
      final y = size.height * (0.9 - life * 0.7);
      final alpha = math.sin(life * math.pi) * 0.4 * env;
      _softDot(
        canvas,
        Offset(x, y),
        3.5,
        Color.lerp(emotion.color, Colors.white, 0.3)!,
        alpha,
      );
    }
  }

  @override
  bool shouldRepaint(_AfterglowPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.emotion != emotion;
}
