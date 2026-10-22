// Tests for the geohash helpers — coarse, privacy-preserving locations
// (SPEC v0.3: precision 3 = area, precision 5 = city, never exact).

import 'package:emosphere/core/geo/geohash.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('encode', () {
    test('matches the reference implementation (Prague)', () {
      expect(Geohash.encode(50.0755, 14.4378, precision: 5), 'u2fkb');
      expect(Geohash.encode(50.0755, 14.4378, precision: 3), 'u2f');
    });

    test('matches reference values around the world', () {
      expect(Geohash.encode(37.7749, -122.4194, precision: 5), '9q8yy');
      expect(Geohash.encode(49.1951, 16.6068, precision: 5), 'u2ezc');
      expect(Geohash.encode(-33.8688, 151.2093, precision: 5), 'r3gx2');
    });

    test('defaults to city precision (5)', () {
      expect(Geohash.encode(50.0755, 14.4378), 'u2fkb');
      expect(Geohash.encode(50.0755, 14.4378).length, Geohash.cityPrecision);
    });

    test('corner coordinates stay in range', () {
      expect(Geohash.encode(90, 180, precision: 5), 'zzzzz');
      expect(Geohash.encode(0, 0, precision: 5), 's0000');
      expect(Geohash.encode(-90, -180, precision: 3), '000');
    });

    test('honours the requested precision length', () {
      expect(Geohash.encode(50.0755, 14.4378, precision: 12), hasLength(12));
      expect(Geohash.encode(50.0755, 14.4378, precision: 1), hasLength(1));
    });
  });

  group('decode / bounds', () {
    test('decodes to the centre of the cell', () {
      final center = Geohash.decode('u2fkb');
      expect(center.latitude, closeTo(50.075684, 1e-5));
      expect(center.longitude, closeTo(14.436035, 1e-5));
    });

    test('bounds contain the encoded point', () {
      final bounds = Geohash.bounds('u2fkb');
      expect(bounds.latMin, lessThanOrEqualTo(50.0755));
      expect(bounds.latMax, greaterThanOrEqualTo(50.0755));
      expect(bounds.lonMin, lessThanOrEqualTo(14.4378));
      expect(bounds.lonMax, greaterThanOrEqualTo(14.4378));
      expect(
        bounds.center.latitude,
        closeTo(Geohash.decode('u2fkb').latitude, 1e-9),
      );
    });

    test('an area cell fully contains its city cells', () {
      final area = Geohash.bounds('u2f');
      final city = Geohash.bounds('u2fkb');
      expect(area.latMin, lessThanOrEqualTo(city.latMin));
      expect(area.latMax, greaterThanOrEqualTo(city.latMax));
      expect(area.lonMin, lessThanOrEqualTo(city.lonMin));
      expect(area.lonMax, greaterThanOrEqualTo(city.lonMax));
    });

    test('an empty geohash is the whole world', () {
      final bounds = Geohash.bounds('');
      expect(bounds.latMin, -90);
      expect(bounds.latMax, 90);
      expect(bounds.lonMin, -180);
      expect(bounds.lonMax, 180);
    });

    test('invalid characters throw a FormatException', () {
      expect(() => Geohash.bounds('a1b2c'), throwsFormatException);
    });
  });

  group('parent', () {
    test('truncates to the requested precision', () {
      expect(Geohash.parent('u2fkb', 3), 'u2f');
      expect(Geohash.parent('u2fkb', 5), 'u2fkb');
      expect(Geohash.parent('u2f', 5), 'u2f');
    });

    test('encoding then truncating keeps the point (coarse cells)', () {
      const lat = 50.0755;
      const lon = 14.4378;
      final city = Geohash.encode(lat, lon, precision: 5);
      final area = Geohash.parent(city, 3);
      final bounds = Geohash.bounds(area);
      expect(bounds.latMin, lessThanOrEqualTo(lat));
      expect(bounds.latMax, greaterThanOrEqualTo(lat));
      expect(bounds.lonMin, lessThanOrEqualTo(lon));
      expect(bounds.lonMax, greaterThanOrEqualTo(lon));
    });

    test('rejects non-positive precision', () {
      expect(() => Geohash.parent('u2f', 0), throwsArgumentError);
      expect(() => Geohash.parent('u2f', -1), throwsArgumentError);
    });
  });

  test('precision constants follow the SPEC', () {
    expect(Geohash.areaPrecision, 6);
    expect(Geohash.cityPrecision, 5);
  });

  test('GeoPoint compares by value', () {
    expect(const GeoPoint(1, 2), const GeoPoint(1, 2));
    expect(const GeoPoint(1, 2).hashCode, const GeoPoint(1, 2).hashCode);
    expect(const GeoPoint(1, 2), isNot(const GeoPoint(1, 3)));
  });
}
