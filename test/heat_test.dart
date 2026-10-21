// Tests for the map heat-layer geometry (card 3/7): zoom bands, cell radius,
// opacity, tap resolution and friend-cell detection.

import 'package:emosphere/core/geo/aggregate.dart';
import 'package:emosphere/core/geo/geohash.dart';
import 'package:emosphere/core/geo/heat.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prague city centre, geohash precision 5 (the check-in precision).
const String pragueCell = 'u2fkb';

/// Prague at the coarser precision 4 (a city-sized map cell).
const String pragueCell4 = 'u2fk';

/// Brno, precision 5 — about 183 km from the Prague cell centre.
const String brnoCell = 'u2ezc';

CheckinEvent _checkin({
  required String id,
  required String pubkey,
  Emotion emotion = Emotion.calm,
  int intensity = 3,
  String? geohash,
  DateTime? createdAt,
}) {
  return CheckinEvent(
    id: id,
    pubkey: pubkey,
    emotion: emotion,
    intensity: intensity,
    geohash: geohash,
    createdAt: createdAt ?? DateTime.utc(2026, 10, 21, 12),
  );
}

/// The aggregate of [geohash] built from [events] at its own precision.
CellAggregate _cell(String geohash, List<CheckinEvent> events) {
  final cells = aggregateByCell(events, precision: geohash.length);
  return cells.firstWhere((cell) => cell.geohash == geohash);
}

void main() {
  group('precisionForZoom', () {
    test('uses coarse cells while zoomed out and fine cells up close', () {
      expect(precisionForZoom(0), 1);
      expect(precisionForZoom(3.9), 1);
      expect(precisionForZoom(4), 2);
      expect(precisionForZoom(5.9), 2);
      expect(precisionForZoom(6), 3);
      expect(precisionForZoom(8.9), 3);
      expect(precisionForZoom(9), 4);
      expect(precisionForZoom(11.9), 4);
      expect(precisionForZoom(12), 5);
      expect(precisionForZoom(18), 5);
    });

    test('never gets coarser as the zoom grows', () {
      var previous = precisionForZoom(1);
      for (var zoom = 1.0; zoom <= 18; zoom += 0.5) {
        final current = precisionForZoom(zoom);
        expect(current, greaterThanOrEqualTo(previous), reason: 'zoom $zoom');
        previous = current;
      }
    });
  });

  group('cellSizeMeters', () {
    test('grows with the cell', () {
      expect(cellSizeMeters('u'), greaterThan(cellSizeMeters('u2f')));
      expect(cellSizeMeters('u2f'), greaterThan(cellSizeMeters(pragueCell)));
    });

    test('matches the real size of a central-European cell', () {
      // Precision 3 in central Europe: 100 km east-west, 156 km north-south.
      expect(cellSizeMeters('u2f'), inInclusiveRange(50000, 200000));
      // Precision 5 in central Europe: roughly 3–5 km.
      expect(cellSizeMeters(pragueCell), inInclusiveRange(2000, 6000));
    });
  });

  group('heatRadiusMeters', () {
    test('is proportional to the cell size and never zero', () {
      final city = heatRadiusMeters(pragueCell);
      final country = heatRadiusMeters('u2f');
      expect(country, greaterThan(city));
      expect(city, greaterThan(0));
    });

    test('clamps to the drawing limits', () {
      expect(heatRadiusMeters('u', factor: 100), maxHeatRadiusMeters);
      expect(
        heatRadiusMeters(pragueCell, factor: 0.00001),
        minHeatRadiusMeters,
      );
    });
  });

  group('heatOpacity', () {
    test('grows with the count and stops at the maximum', () {
      final one = heatOpacity(1, maxCount: 50);
      final ten = heatOpacity(10, maxCount: 50);
      final fifty = heatOpacity(50, maxCount: 50);

      expect(one, lessThan(ten));
      expect(ten, lessThan(fifty));
      expect(fifty, closeTo(0.74, 0.0001));
    });

    test('uses the minimum for empty or negative counts', () {
      expect(heatOpacity(0), 0.24);
      expect(heatOpacity(-3), 0.24);
    });

    test('a single check-in in the window is the brightest cell', () {
      expect(heatOpacity(1, maxCount: 1), closeTo(0.74, 0.0001));
    });

    test('never leaves the configured bounds', () {
      for (final count in <int>[1, 2, 7, 40, 500]) {
        for (final maxCount in <int>[1, 3, 500]) {
          final opacity = heatOpacity(count, maxCount: maxCount);
          expect(opacity, inInclusiveRange(0.24, 0.74));
        }
      }
    });
  });

  group('distanceMeters', () {
    test('is zero for the same point', () {
      final point = Geohash.decode(pragueCell);
      expect(distanceMeters(point, point), 0);
    });

    test('matches the Prague–Brno great circle distance', () {
      final prague = Geohash.decode(pragueCell);
      final brno = Geohash.decode(brnoCell);
      // Real distance is about 184 km; the cell centres shift it a little.
      expect(distanceMeters(prague, brno), inInclusiveRange(150000, 230000));
    });
  });

  group('cellAt', () {
    final events = <CheckinEvent>[
      _checkin(id: 'a', pubkey: 'aa', geohash: pragueCell),
      _checkin(id: 'b', pubkey: 'bb', geohash: brnoCell),
    ];

    test('resolves a tap inside a cell to that cell', () {
      final prague = _cell(pragueCell4, events);
      final brno = _cell(brnoCell, events);
      expect(cellAt(<CellAggregate>[prague, brno], prague.center), prague);
      expect(cellAt(<CellAggregate>[prague, brno], brno.center), brno);
    });

    test('returns null for a tap far from every cell', () {
      final cells = <CellAggregate>[_cell(pragueCell4, events)];
      const ocean = GeoPoint(0, -30);
      expect(cellAt(cells, ocean), isNull);
    });

    test('picks the nearest cell when two circles overlap', () {
      final city = _cell(pragueCell4, events);
      final fine = _cell(pragueCell, events);
      // A point a few hundred metres from the fine cell centre: inside both
      // circles, but nearest to the fine one.
      final center = Geohash.decode(pragueCell);
      final nearby = GeoPoint(
        center.latitude + 0.002,
        center.longitude + 0.002,
      );
      expect(cellAt(<CellAggregate>[city, fine], nearby), fine);
    });
  });

  group('friendCellHashes', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    final friendKey = 'bb${'2' * 62}';
    final events = <CheckinEvent>[
      _checkin(
        id: 'mine',
        pubkey: 'aa${'1' * 62}',
        geohash: pragueCell,
        createdAt: now,
      ),
      _checkin(
        id: 'friend',
        pubkey: friendKey,
        geohash: brnoCell,
        createdAt: now,
      ),
      _checkin(id: 'friend-no-location', pubkey: friendKey, createdAt: now),
    ];

    test('marks the cells of friends only, at the aggregation precision', () {
      final hashes = friendCellHashes(events, <String>[
        friendKey,
      ], precision: 3);
      expect(hashes, <String>{Geohash.parent(brnoCell, 3)});
      expect(hashes, isNot(contains(Geohash.parent(pragueCell, 3))));
    });

    test('matches the author case-insensitively and ignores padding', () {
      final hashes = friendCellHashes(events, <String>[
        '  ${friendKey.toUpperCase()}  ',
      ], precision: 3);
      expect(hashes, hasLength(1));
    });

    test('returns an empty set without friends', () {
      expect(friendCellHashes(events, const <String>[], precision: 3), isEmpty);
    });
  });
}
