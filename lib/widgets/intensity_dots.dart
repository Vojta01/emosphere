// Five dots visualising the 1–5 check-in intensity (shared by the feed and
// the history screens).
//
// The widget is deliberately tiny: callers pass the emotion colour and the
// dot size; filled dots get a slight transparency so they blend into the
// dark cards.

import 'package:flutter/material.dart';

/// Five dots, [intensity] of them filled in [color].
class IntensityDots extends StatelessWidget {
  const IntensityDots({
    super.key,
    required this.intensity,
    required this.color,
    this.dotSize = 6,
  });

  /// Number of filled dots (the model clamps it to 1–5).
  final int intensity;

  /// Colour of the filled dots.
  final Color color;

  /// Diameter of one dot.
  final double dotSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Container(
            width: dotSize,
            height: dotSize,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= intensity
                  ? color.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
      ],
    );
  }
}
