// Heat-layer geometry for the world map (card 3).
//
// Pure functions over [CellAggregate] and the map zoom: they choose the geohash
// precision for a zoom band, turn a cell into a circle radius / opacity, and
// resolve which cell a tap hit. Keeping the maths here (instead of inside the
// map screen) keeps it unit-testable without the flutter_map widget tree.

import 'dart:math' as math;

import '../models/checkin.dart';
import 'aggregate.dart';
import 'geohash.dart';

/// Metres per degree of latitude (spherical approximation).
const double _metersPerDegree = 111320;

/// Geohash precision used at [zoom] — coarser cells while zoomed out.
///
/// The bands keep a heat cell at roughly a fifth of the visible world width.
/// Mean side of the cell at the equator: precision 1 ≈ 5000 km, 2 ≈ 880 km,
/// 3 ≈ 156 km, 4 ≈ 28 km, 5 ≈ 4.9 km.
int precisionForZoom(double zoom) {
  if (zoom < 4) {
    return 1;
  }
  if (zoom < 6) {
    return 2;
  }
  if (zoom < 9) {
    return 3;
  }
  if (zoom < 12) {
    return 4;
  }
  return 5;
}

/// Mean side of one geohash cell in metres (geometric mean of its sides).
///
/// The bound box of the cell is used, so a check-in that only carries a coarse
/// geohash keeps its real (larger) footprint after the aggregation.
double cellSizeMeters(String geohash) {
  final bounds = Geohash.bounds(geohash);
  final midLat = (bounds.latMin + bounds.latMax) / 2;
  final latMeters = (bounds.latMax - bounds.latMin).abs() * _metersPerDegree;
  final lonMeters =
      (bounds.lonMax - bounds.lonMin).abs() *
      _metersPerDegree *
      math.cos(midLat * math.pi / 180).abs();
  return math.sqrt(latMeters * lonMeters);
}

/// Lowest / highest radius the heat layer draws (metres).
const double minHeatRadiusMeters = 400;
const double maxHeatRadiusMeters = 2600000;

/// Circle radius (metres) of the heat cell [geohash].
///
/// [factor] slightly over one half makes neighbouring cells overlap, which is
/// what turns the individual circles into a continuous heat layer.
double heatRadiusMeters(String geohash, {double factor = 0.62}) {
  final radius = cellSizeMeters(geohash) * factor;
  return radius.clamp(minHeatRadiusMeters, maxHeatRadiusMeters);
}

/// Opacity of a heat circle, growing with the number of check-ins.
///
/// Logarithmic, so the first few check-ins are visible while a busy cell does
/// not become fully opaque. [maxCount] is the busiest cell of the current
/// window (defaults to a single check-in, i.e. the minimum opacity).
double heatOpacity(
  int count, {
  int maxCount = 1,
  double min = 0.24,
  double max = 0.74,
}) {
  if (count <= 0) {
    return min;
  }
  final reference = maxCount < 1 ? 1 : maxCount;
  final ratio = math.log(1 + count) / math.log(1 + reference);
  return (min + (max - min) * ratio).clamp(min, max);
}

/// Great-circle distance between [a] and [b] in metres (haversine).
double distanceMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLat = lat2 - lat1;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final h =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
}

/// The cell under [point] — the nearest cell whose circle contains the tap.
///
/// [tolerance] widens the circle a little so a tap next to a small cell still
/// hits it. Returns `null` when the tap did not land on any cell.
CellAggregate? cellAt(
  Iterable<CellAggregate> cells,
  GeoPoint point, {
  double tolerance = 1.6,
}) {
  CellAggregate? best;
  var bestDistance = double.infinity;
  for (final cell in cells) {
    final distance = distanceMeters(cell.center, point);
    final reach = heatRadiusMeters(cell.geohash) * tolerance;
    if (distance > reach || distance >= bestDistance) {
      continue;
    }
    best = cell;
    bestDistance = distance;
  }
  return best;
}

/// Geohashes of the cells that hold at least one check-in of [friendPubkeys].
///
/// The map draws a distinct ring around these cells. Events without a geohash
/// are skipped, exactly like the aggregation does.
Set<String> friendCellHashes(
  Iterable<CheckinEvent> events,
  Iterable<String> friendPubkeys, {
  required int precision,
}) {
  final friends = <String>{
    for (final key in friendPubkeys) key.trim().toLowerCase(),
  };
  if (friends.isEmpty) {
    return <String>{};
  }
  final result = <String>{};
  for (final event in events) {
    final geohash = event.geohash;
    if (geohash == null || geohash.isEmpty) {
      continue;
    }
    if (!friends.contains(event.pubkey.trim().toLowerCase())) {
      continue;
    }
    result.add(Geohash.parent(geohash, precision));
  }
  return result;
}
