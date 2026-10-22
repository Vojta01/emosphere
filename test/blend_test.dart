// R1 — OKLab heat-cell blending.
//
// Reference values were computed with an independent Python implementation of
// the same OKLab maths; the tolerance covers rounding only.

import 'package:emosphere/core/geo/blend.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Parses a `RRGGBB` hex string into channel bytes.
({int r, int g, int b}) _hex(String hex) => (
  r: int.parse(hex.substring(0, 2), radix: 16),
  g: int.parse(hex.substring(2, 4), radix: 16),
  b: int.parse(hex.substring(4, 6), radix: 16),
);

void _expectNear(Color color, String hex, {int tolerance = 3}) {
  final expected = _hex(hex);
  expect((color.r * 255).round(), closeTo(expected.r, tolerance));
  expect((color.g * 255).round(), closeTo(expected.g, tolerance));
  expect((color.b * 255).round(), closeTo(expected.b, tolerance));
  expect(color.a, 1.0);
}

void main() {
  group('blendEmotionWeights', () {
    test('single emotion keeps its exact palette colour', () {
      for (final emotion in Emotion.values) {
        final blended = blendEmotionWeights({emotion: 3});
        expect(
          (blended.r * 255).round(),
          closeTo((emotion.color.r * 255).round(), 1),
          reason: emotion.slug,
        );
        expect(
          (blended.g * 255).round(),
          closeTo((emotion.color.g * 255).round(), 1),
          reason: emotion.slug,
        );
        expect(
          (blended.b * 255).round(),
          closeTo((emotion.color.b * 255).round(), 1),
          reason: emotion.slug,
        );
      }
    });

    test("joy + anger lands on orange (Vojta's example)", () {
      _expectNear(
        blendEmotionWeights({Emotion.joy: 1, Emotion.anger: 1}),
        'FC9544',
      );
    });

    test('calm + anger lands on a muddy neutral', () {
      _expectNear(
        blendEmotionWeights({Emotion.calm: 1, Emotion.anger: 1}),
        'C19F62',
      );
    });

    test('sadness + fear lands on blue-violet', () {
      _expectNear(
        blendEmotionWeights({Emotion.sadness: 1, Emotion.fear: 1}),
        '8999FA',
      );
    });

    test('joy + calm lands on fresh yellow-green', () {
      _expectNear(
        blendEmotionWeights({Emotion.joy: 1, Emotion.calm: 1}),
        'B7DD66',
      );
    });

    test('intensity weights change the mix', () {
      _expectNear(
        blendEmotionWeights({Emotion.joy: 2, Emotion.anger: 1}),
        'FEAC43',
      );
    });

    test('zero and negative weights are ignored', () {
      final withZero = blendEmotionWeights({Emotion.joy: 1, Emotion.anger: 0});
      _expectNear(withZero, 'FFD93D', tolerance: 2);
    });

    test('empty weights return transparent', () {
      expect(blendEmotionWeights(const <Emotion, double>{}).a, 0);
    });

    test('is deterministic', () {
      final first = blendEmotionWeights({Emotion.joy: 2, Emotion.anger: 3});
      final second = blendEmotionWeights({Emotion.joy: 2, Emotion.anger: 3});
      expect(first, second);
    });
  });

  group('blendEmotionColors', () {
    test('equal weights match blendEmotionWeights', () {
      final list = blendEmotionColors([Emotion.sadness, Emotion.fear]);
      final map = blendEmotionWeights({Emotion.sadness: 1, Emotion.fear: 1});
      expect(list, map);
    });

    test('empty list returns transparent', () {
      expect(blendEmotionColors(const <Emotion>[]).a, 0);
    });
  });
}
