// R9 — time machine: the sliding-window filter and the instant label.

import 'package:emosphere/core/geo/aggregate.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/widgets/timeline_bar.dart';
import 'package:flutter_test/flutter_test.dart';

CheckinEvent _at(DateTime instant) => CheckinEvent(
  id: 'ck-${instant.millisecondsSinceEpoch}',
  pubkey: 'aa${'0' * 62}',
  emotion: Emotion.joy,
  intensity: 3,
  createdAt: instant,
);

void main() {
  final end = DateTime.utc(2026, 10, 23, 12);

  group('filterBySlidingWindow', () {
    test('keeps only check-ins inside [end - duration, end]', () {
      final inside = <CheckinEvent>[
        _at(end.subtract(const Duration(hours: 5))),
        _at(end.subtract(const Duration(milliseconds: 1))),
        _at(end),
      ];
      final outside = <CheckinEvent>[
        // Just before the cutoff.
        _at(end.subtract(const Duration(hours: 6, milliseconds: 1))),
        // The future is not part of the past.
        _at(end.add(const Duration(hours: 1))),
      ];

      final kept = filterBySlidingWindow(
        <CheckinEvent>[...inside, ...outside],
        end: end,
        duration: const Duration(hours: 6),
      );

      expect(
        kept.map((event) => event.createdAt).toList(),
        <DateTime>[for (final event in inside) event.createdAt],
      );
    });

    test('a one-hour replay window drops an event from two hours ago', () {
      final recent = _at(end.subtract(const Duration(minutes: 30)));
      final events = <CheckinEvent>[
        _at(end.subtract(const Duration(hours: 2))),
        recent,
      ];

      final kept = filterBySlidingWindow(
        events,
        end: end,
        duration: const Duration(hours: 1),
      );

      expect(kept.map((event) => event.id).toList(), <String>[recent.id]);
    });
  });

  group('formatMachineLabel', () {
    test('czech: weekday, day, month and time', () {
      expect(
        formatMachineLabel(DateTime(2026, 10, 23, 14, 30), 'cs'),
        'pá 23. 10. · 14:30',
      );
    });

    test('english: abbreviated weekday and month', () {
      expect(
        formatMachineLabel(DateTime(2026, 10, 23, 14, 30), 'en'),
        'Fri 23 Oct · 14:30',
      );
    });

    test('pads single-digit hours and minutes', () {
      expect(
        formatMachineLabel(DateTime(2026, 10, 23, 0, 5), 'cs'),
        'pá 23. 10. · 00:05',
      );
    });
  });
}
