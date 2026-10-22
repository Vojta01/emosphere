// Geohash encoding/decoding (used for coarse, privacy-preserving locations).
//
// EmoSphere only ever stores precision 5 ("city") or precision 6 ("area")
// geohashes — never the exact position (SPEC v0.3).

/// A WGS84 coordinate pair.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  /// Latitude in degrees (-90..90).
  final double latitude;

  /// Longitude in degrees (-180..180).
  final double longitude;

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Static geohash helpers (standard base-32 geohash, like geohash.org).
class Geohash {
  Geohash._();

  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Precision used for the "area" location setting (~1.2 km x 0.6 km cell —
  /// a neighbourhood-sized area with a radius of roughly 0.5 km).
  static const int areaPrecision = 6;

  /// Precision used for the "city" location setting (~4.9 km x 4.9 km).
  static const int cityPrecision = 5;

  /// Encodes [latitude]/[longitude] into a geohash of [precision] characters.
  static String encode(
    double latitude,
    double longitude, {
    int precision = cityPrecision,
  }) {
    assert(precision >= 1 && precision <= 12, 'precision must be 1..12');
    var latMin = -90.0;
    var latMax = 90.0;
    var lonMin = -180.0;
    var lonMax = 180.0;
    final buffer = StringBuffer();
    var bits = 0;
    var bitCount = 0;
    var evenBit = true;
    while (buffer.length < precision) {
      if (evenBit) {
        final mid = (lonMin + lonMax) / 2;
        if (longitude >= mid) {
          bits = (bits << 1) | 1;
          lonMin = mid;
        } else {
          bits = bits << 1;
          lonMax = mid;
        }
      } else {
        final mid = (latMin + latMax) / 2;
        if (latitude >= mid) {
          bits = (bits << 1) | 1;
          latMin = mid;
        } else {
          bits = bits << 1;
          latMax = mid;
        }
      }
      evenBit = !evenBit;
      bitCount++;
      if (bitCount == 5) {
        buffer.write(_base32[bits]);
        bits = 0;
        bitCount = 0;
      }
    }
    return buffer.toString();
  }

  /// Decodes [geohash] into the centre point of its cell.
  static GeoPoint decode(String geohash) {
    final cell = bounds(geohash);
    return GeoPoint(
      (cell.latMin + cell.latMax) / 2,
      (cell.lonMin + cell.lonMax) / 2,
    );
  }

  /// Returns the bounding box of [geohash].
  static GeohashBounds bounds(String geohash) {
    var latMin = -90.0;
    var latMax = 90.0;
    var lonMin = -180.0;
    var lonMax = 180.0;
    var evenBit = true;
    final value = geohash.toLowerCase();
    for (var i = 0; i < value.length; i++) {
      final index = _base32.indexOf(value[i]);
      if (index < 0) {
        throw FormatException('Invalid geohash character: ${value[i]}');
      }
      for (var bit = 4; bit >= 0; bit--) {
        final bitValue = (index >> bit) & 1;
        if (evenBit) {
          final mid = (lonMin + lonMax) / 2;
          if (bitValue == 1) {
            lonMin = mid;
          } else {
            lonMax = mid;
          }
        } else {
          final mid = (latMin + latMax) / 2;
          if (bitValue == 1) {
            latMin = mid;
          } else {
            latMax = mid;
          }
        }
        evenBit = !evenBit;
      }
    }
    return GeohashBounds(
      latMin: latMin,
      latMax: latMax,
      lonMin: lonMin,
      lonMax: lonMax,
    );
  }

  /// Returns the [precision]-character parent cell of [geohash]
  /// (for example `u2fkb` at precision 3 is `u2f`).
  static String parent(String geohash, int precision) {
    if (precision <= 0) {
      throw ArgumentError.value(precision, 'precision', 'must be positive');
    }
    if (geohash.length <= precision) {
      return geohash;
    }
    return geohash.substring(0, precision);
  }
}

/// Bounding box of a geohash cell.
class GeohashBounds {
  const GeohashBounds({
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
  });

  /// Southern edge.
  final double latMin;

  /// Northern edge.
  final double latMax;

  /// Western edge.
  final double lonMin;

  /// Eastern edge.
  final double lonMax;

  /// Centre of the box.
  GeoPoint get center => GeoPoint((latMin + latMax) / 2, (lonMin + lonMax) / 2);
}
