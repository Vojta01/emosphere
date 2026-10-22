// OKLab colour blending for the heat map (R1).
//
// The colour of a heat cell is the intensity-weighted average of the colours
// of all its check-ins, computed in OKLab (a perceptually uniform space) so
// that mixing two emotions lands on a colour the eye reads as "in between".
// Examples: joy + anger → orange; calm + anger → a muddy grey-brown neutral.
//
// The maths is pure and unit-tested; the map screen only consumes the result.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/emotion.dart';

/// Blends the palette colours of [weights] (emotion → intensity weight).
///
/// Returns a fully opaque colour. When [weights] is empty or carries no
/// positive weight, transparent is returned so callers can skip drawing.
Color blendEmotionWeights(Map<Emotion, double> weights) {
  var total = 0.0;
  var l = 0.0;
  var a = 0.0;
  var b = 0.0;
  weights.forEach((emotion, weight) {
    if (weight <= 0) {
      return;
    }
    final lab = _srgbToOklab(emotion.color);
    total += weight;
    l += lab.$1 * weight;
    a += lab.$2 * weight;
    b += lab.$3 * weight;
  });
  if (total <= 0) {
    return const Color(0x00000000);
  }
  return _oklabToColor(l / total, a / total, b / total);
}

/// Blends the colours of [emotions] with equal weights.
Color blendEmotionColors(Iterable<Emotion> emotions) {
  final weights = <Emotion, double>{};
  for (final emotion in emotions) {
    weights[emotion] = (weights[emotion] ?? 0) + 1;
  }
  return blendEmotionWeights(weights);
}

// -- sRGB <-> OKLab (Björn Ottosson's conversion) --------------------------

/// Converts a colour to OKLab (L, a, b). Input channels are treated as sRGB.
(double, double, double) _srgbToOklab(Color color) {
  final r = _linearize(color.r);
  final g = _linearize(color.g);
  final b = _linearize(color.b);

  final l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b;
  final m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b;
  final s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b;

  final l_ = math.pow(l, 1 / 3).toDouble();
  final m_ = math.pow(m, 1 / 3).toDouble();
  final s_ = math.pow(s, 1 / 3).toDouble();

  return (
    0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
    1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
    0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_,
  );
}

/// Converts OKLab coordinates back to an opaque sRGB colour (clamped).
Color _oklabToColor(double l, double a, double b) {
  final l_ = l + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = l - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = l - 0.0894841775 * a - 1.2914855480 * b;

  final l3 = l_ * l_ * l_;
  final m3 = m_ * m_ * m_;
  final s3 = s_ * s_ * s_;

  final r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3;
  final g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3;
  final bl = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3;

  return Color.fromARGB(
    255,
    _delinearize(r),
    _delinearize(g),
    _delinearize(bl),
  );
}

/// sRGB channel (0..1) → linear-light channel.
double _linearize(double channel) {
  return channel <= 0.04045
      ? channel / 12.92
      : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
}

/// Linear-light channel → sRGB byte (0..255), clamped to the gamut.
int _delinearize(double channel) {
  final clamped = channel.clamp(0.0, 1.0);
  final srgb = clamped <= 0.0031308
      ? clamped * 12.92
      : 1.055 * math.pow(clamped, 1 / 2.4) - 0.055;
  return (srgb * 255).round().clamp(0, 255);
}
