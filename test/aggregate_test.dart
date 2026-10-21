// Tests for the map aggregation — dominant emotion (intensity-weighted),
// per-cell grouping, counts and the 1 h / 24 h / 7 d windows (SPEC v0.3).

import 'package:emosphere/core/geo/aggregate.dart';
import 'package:emosphere/core/geo/geohash.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds a check-in with a deterministic id.
CheckinEvent checkin(
  Emotion emotion,
  DateTime createdAt, {
  int intensity = 3,
  String? geohash,
  String pubkey =
      'aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11',
}) {
  return CheckinEvent(
    id: 'id-${createdAt.microsecondsSinceEpoch}-${emotion.slug}-$intensity',
    pubkey: pubkey,
    emotion: emotion,
    intensity: intensity,
    geohash: geohash,
    createdAt: createdAt,
  );
}

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  group('dominantEmotion', () {
    test('returns null for an empty list', () {
      expect(dominantEmotion(const <CheckinEvent>[]), isNull);
    });

    test('weights intensity over the raw count', () {
      // joy: 2 check-ins x intensity 1 = weight 2
      // sadness: 1 check-in x intensity 5 = weight 5
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, intensity: 1),
        checkin(Emotion.joy, now, intensity: 1),
        checkin(Emotion.sadness, now, intensity: 5),
      ];
      expect(dominantEmotion(events), Emotion.sadness);
    });

    test('breaks a weight tie by the check-in count', () {
      // joy: 3 x 1 = weight 3 (count 3); fear: 1 x 3 = weight 3 (count 1)
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, intensity: 1),
        checkin(Emotion.joy, now, intensity: 1),
        checkin(Emotion.joy, now, intensity: 1),
        checkin(Emotion.fear, now, intensity: 3),
      ];
      expect(dominantEmotion(events), Emotion.joy);
    });

    test('breaks a full tie by the canonical emotion order', () {
      final events = <CheckinEvent>[
        checkin(Emotion.calm, now, intensity: 3),
        checkin(Emotion.joy, now, intensity: 3),
      ];
      expect(dominantEmotion(events), Emotion.joy);
    });

    test('ignores the event order', () {
      final events = <CheckinEvent>[
        checkin(Emotion.anger, now, intensity: 2),
        checkin(Emotion.anger, now, intensity: 2),
        checkin(Emotion.love, now, intensity: 3),
        checkin(Emotion.love, now, intensity: 3),
      ];
      expect(dominantEmotion(events), Emotion.love);
    });
  });

  group('filterByWindow', () {
    final events = <CheckinEvent>[
      checkin(Emotion.joy, now.subtract(const Duration(minutes: 30))),
      checkin(Emotion.joy, now.subtract(const Duration(hours: 2))),
      checkin(Emotion.joy, now.subtract(const Duration(days: 3))),
      checkin(Emotion.joy, now.subtract(const Duration(days: 8))),
    ];

    test('1 h keeps only the last hour', () {
      final result = filterByWindow(events, MapWindow.hours1, now: now);
      expect(result, hasLength(1));
      expect(
        result.single.createdAt,
        now.subtract(const Duration(minutes: 30)),
      );
    });

    test('24 h keeps the last day', () {
      final result = filterByWindow(events, MapWindow.hours24, now: now);
      expect(result, hasLength(2));
    });

    test('7 d keeps everything younger than a week', () {
      final result = filterByWindow(events, MapWindow.days7, now: now);
      expect(result, hasLength(3));
      expect(
        result.any(
          (event) => event.createdAt == now.subtract(const Duration(days: 8)),
        ),
        isFalse,
      );
    });

    test('the window edge is inclusive', () {
      final edge = <CheckinEvent>[
        checkin(Emotion.joy, now.subtract(const Duration(hours: 1))),
      ];
      expect(filterByWindow(edge, MapWindow.hours1, now: now), hasLength(1));
    });
  });

  group('aggregateByCell', () {
    test('groups by cell, counts and weights by intensity', () {
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, intensity: 5, geohash: 'u2fkb'),
        checkin(Emotion.joy, now, intensity: 1, geohash: 'u2fkb'),
        checkin(Emotion.sadness, now, intensity: 4, geohash: 'u2fkb'),
        checkin(Emotion.calm, now, intensity: 2, geohash: 'u2ezc'),
      ];
      final cells = aggregateByCell(events);

      expect(cells, hasLength(2));
      // Sorted by count (descending): Prague cell first.
      final prague = cells.first;
      expect(prague.geohash, 'u2fkb');
      expect(prague.count, 3);
      expect(prague.counts[Emotion.joy], 2);
      expect(prague.counts[Emotion.sadness], 1);
      expect(prague.weights[Emotion.joy], 6);
      expect(prague.weights[Emotion.sadness], 4);
      expect(prague.dominant, Emotion.joy);
      expect(prague.totalWeight, 10);
      expect(prague.shareOf(Emotion.joy), closeTo(0.6, 1e-9));
      expect(prague.center.latitude, closeTo(50.075684, 1e-5));

      final brno = cells.last;
      expect(brno.geohash, 'u2ezc');
      expect(brno.count, 1);
      expect(brno.dominant, Emotion.calm);
    });

    test('skips check-ins without a geohash (location off)', () {
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, geohash: null),
        checkin(Emotion.anger, now, geohash: 'u2fkb'),
      ];
      final cells = aggregateByCell(events);
      expect(cells, hasLength(1));
      expect(cells.single.count, 1);
      expect(cells.single.dominant, Emotion.anger);
    });

    test('precision 3 merges city cells into one area cell', () {
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, geohash: 'u2fkb'),
        checkin(Emotion.calm, now, geohash: 'u2fzz'),
      ];
      final merged = aggregateByCell(events, precision: Geohash.areaPrecision);
      expect(merged, hasLength(1));
      expect(merged.single.geohash, 'u2f');
      expect(merged.single.count, 2);
      expect(merged.single.counts[Emotion.joy], 1);
      expect(merged.single.counts[Emotion.calm], 1);
    });

    test('breaks count ties by geohash so the order is deterministic', () {
      final events = <CheckinEvent>[
        checkin(Emotion.joy, now, geohash: 'u2ezc'),
        checkin(Emotion.joy, now, geohash: 'u2fkb'),
      ];
      final cells = aggregateByCell(events);
      expect(cells.map((cell) => cell.geohash), <String>['u2ezc', 'u2fkb']);
    });
  });

  group('aggregateWindow', () {
    test('filters by window and aggregates the rest', () {
      final events = <CheckinEvent>[
        checkin(
          Emotion.joy,
          now.subtract(const Duration(minutes: 10)),
          intensity: 2,
          geohash: 'u2fkb',
        ),
        checkin(
          Emotion.sadness,
          now.subtract(const Duration(hours: 5)),
          intensity: 5,
          geohash: 'u2fkb',
        ),
        checkin(
          Emotion.anger,
          now.subtract(const Duration(days: 3)),
          intensity: 5,
          geohash: 'u2fkb',
        ),
      ];

      final lastHour = aggregateWindow(events, MapWindow.hours1, now: now);
      expect(lastHour.single.count, 1);
      expect(lastHour.single.dominant, Emotion.joy);

      final lastDay = aggregateWindow(events, MapWindow.hours24, now: now);
      expect(lastDay.single.count, 2);
      // sadness x5 outweighs joy x2 in the same cell.
      expect(lastDay.single.dominant, Emotion.sadness);

      final lastWeek = aggregateWindow(events, MapWindow.days7, now: now);
      expect(lastWeek.single.count, 3);
      // anger x5 and sadness x5 tie on weight and count → the canonical
      // emotion order (sadness before anger) decides.
      expect(lastWeek.single.dominant, Emotion.sadness);
    });

    test('area precision collapses neighbouring cities', () {
      final events = <CheckinEvent>[
        checkin(
          Emotion.joy,
          now.subtract(const Duration(hours: 1)),
          geohash: 'u2fkb',
        ),
        checkin(
          Emotion.joy,
          now.subtract(const Duration(hours: 2)),
          geohash: 'u2fzz',
        ),
      ];
      final cells = aggregateWindow(
        events,
        MapWindow.hours24,
        precision: 3,
        now: now,
      );
      expect(cells, hasLength(1));
      expect(cells.single.geohash, 'u2f');
      expect(cells.single.count, 2);
    });
  });

  test('MapWindow exposes the SPEC durations and labels', () {
    expect(MapWindow.hours1.duration, const Duration(hours: 1));
    expect(MapWindow.hours24.duration, const Duration(hours: 24));
    expect(MapWindow.days7.duration, const Duration(days: 7));
    expect(MapWindow.days7.label('cs'), '7 dní');
    expect(MapWindow.days7.label('en'), '7 days');
  });
}
