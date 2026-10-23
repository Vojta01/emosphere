// Aggregation of check-ins into map heat cells (SPEC v0.3).
//
// The map shows one cell per geohash; the cell colour is the intensity-
// weighted OKLab blend of all its check-ins (R1) and the glow grows with the
// number of check-ins. The dominant emotion is kept for the cell detail.

import 'dart:ui' show Color;

import '../models/checkin.dart';
import '../models/emotion.dart';
import 'blend.dart';
import 'geohash.dart';

/// Time windows offered by the map screen.
enum MapWindow {
  /// Last hour.
  hours1(Duration(hours: 1)),

  /// Last 24 hours.
  hours24(Duration(hours: 24)),

  /// Last 7 days.
  days7(Duration(days: 7));

  const MapWindow(this.duration);

  /// Length of the window.
  final Duration duration;

  /// Short label shown on the window switcher.
  String label(String lang) {
    switch (this) {
      case MapWindow.hours1:
        return '1 h';
      case MapWindow.hours24:
        return '24 h';
      case MapWindow.days7:
        return lang == 'en' ? '7 days' : '7 dní';
    }
  }
}

/// One aggregated map cell.
class CellAggregate {
  CellAggregate({
    required this.geohash,
    required this.center,
    required this.count,
    required this.counts,
    required this.weights,
    required this.dominant,
  });

  /// Geohash of the cell (precision used for the aggregation).
  final String geohash;

  /// Centre point of the cell.
  final GeoPoint center;

  /// Number of check-ins in the cell.
  final int count;

  /// Check-in count per emotion.
  final Map<Emotion, int> counts;

  /// Intensity-weighted score per emotion.
  final Map<Emotion, double> weights;

  /// Dominant emotion (highest total intensity weight), or `null` when empty.
  final Emotion? dominant;

  /// Cached blend (R1), computed on first access.
  Color? _blendedCache;

  /// Blended colour of the cell: the intensity-weighted OKLab average of all
  /// its check-ins (R1). Transparent when the cell carries no weight.
  Color get blended => _blendedCache ??= blendEmotionWeights(weights);

  /// Total intensity weight of the cell.
  double get totalWeight =>
      weights.values.fold<double>(0, (sum, value) => sum + value);

  /// Weighted share (0..1) of [emotion] inside the cell.
  double shareOf(Emotion emotion) {
    final total = totalWeight;
    if (total <= 0) {
      return 0;
    }
    return (weights[emotion] ?? 0) / total;
  }

  @override
  String toString() =>
      'CellAggregate($geohash, $count check-ins, dominant: ${dominant?.slug})';
}

/// Filters [events] to the given [window] ending at [now].
///
/// Events without a timestamp are dropped.
List<CheckinEvent> filterByWindow(
  Iterable<CheckinEvent> events,
  MapWindow window, {
  DateTime? now,
}) {
  final reference = (now ?? DateTime.now()).toUtc();
  final cutoff = reference.subtract(window.duration);
  return events
      .where((event) => !event.createdAt.toUtc().isBefore(cutoff))
      .toList();
}

/// Filters [events] to the sliding window ending at [end] (R9 time machine).
///
/// Keeps exactly the check-ins with `end - duration <= createdAt <= end`.
/// The upper bound matters: the map must show the state of the world *at*
/// [end], not the check-ins that only arrived later.
List<CheckinEvent> filterBySlidingWindow(
  Iterable<CheckinEvent> events, {
  required DateTime end,
  required Duration duration,
}) {
  final reference = end.toUtc();
  final cutoff = reference.subtract(duration);
  return events.where((event) {
    final created = event.createdAt.toUtc();
    return !created.isBefore(cutoff) && !created.isAfter(reference);
  }).toList();
}

/// Returns the dominant emotion of [events], weighted by intensity.
///
/// Ties are broken by the plain check-in count and finally by the canonical
/// [Emotion] order, so the result is deterministic.
Emotion? dominantEmotion(Iterable<CheckinEvent> events) {
  final weights = <Emotion, double>{};
  final counts = <Emotion, int>{};
  for (final event in events) {
    weights[event.emotion] = (weights[event.emotion] ?? 0) + event.intensity;
    counts[event.emotion] = (counts[event.emotion] ?? 0) + 1;
  }
  if (weights.isEmpty) {
    return null;
  }
  Emotion? best;
  double bestWeight = -1;
  int bestCount = -1;
  for (final emotion in Emotion.values) {
    final weight = weights[emotion];
    if (weight == null) {
      continue;
    }
    final count = counts[emotion] ?? 0;
    final isBetter =
        weight > bestWeight || (weight == bestWeight && count > bestCount);
    if (isBetter) {
      best = emotion;
      bestWeight = weight;
      bestCount = count;
    }
  }
  return best;
}

/// Centre of the check-in cluster inside a cell.
///
/// The geometric centre of a coarse cell is a poor stand-in for its check-ins:
/// a precision-1 cell spans half of Europe, so a Prague cluster used to glow
/// over Scandinavia, and a precision-2 cell glowed over Hungary. Average the
/// check-ins' own (finer) geohash centres instead; fall back to the cell
/// centre only when nothing decodes.
GeoPoint _clusterCenter(List<CheckinEvent> events, String cellGeohash) {
  var lat = 0.0;
  var lon = 0.0;
  var count = 0;
  for (final event in events) {
    final geohash = event.geohash;
    if (geohash == null || geohash.isEmpty) {
      continue;
    }
    final center = Geohash.decode(geohash);
    lat += center.latitude;
    lon += center.longitude;
    count++;
  }
  if (count == 0) {
    return Geohash.decode(cellGeohash);
  }
  return GeoPoint(lat / count, lon / count);
}

/// Groups [events] into map cells of the given geohash [precision].
///
/// Events without a geohash are skipped (location sharing is optional).
/// The returned list is sorted by check-in count (descending), then by geohash.
List<CellAggregate> aggregateByCell(
  Iterable<CheckinEvent> events, {
  int precision = Geohash.cityPrecision,
}) {
  final grouped = <String, List<CheckinEvent>>{};
  for (final event in events) {
    final geohash = event.geohash;
    if (geohash == null || geohash.isEmpty) {
      continue;
    }
    final cell = Geohash.parent(geohash, precision);
    grouped.putIfAbsent(cell, () => <CheckinEvent>[]).add(event);
  }

  final cells = <CellAggregate>[];
  grouped.forEach((geohash, cellEvents) {
    final counts = <Emotion, int>{};
    final weights = <Emotion, double>{};
    for (final event in cellEvents) {
      counts[event.emotion] = (counts[event.emotion] ?? 0) + 1;
      weights[event.emotion] = (weights[event.emotion] ?? 0) + event.intensity;
    }
    cells.add(
      CellAggregate(
        geohash: geohash,
        center: _clusterCenter(cellEvents, geohash),
        count: cellEvents.length,
        counts: counts,
        weights: weights,
        dominant: dominantEmotion(cellEvents),
      ),
    );
  });

  cells.sort((a, b) {
    final byCount = b.count.compareTo(a.count);
    if (byCount != 0) {
      return byCount;
    }
    return a.geohash.compareTo(b.geohash);
  });
  return cells;
}

/// Convenience: aggregates only the events inside [window].
List<CellAggregate> aggregateWindow(
  Iterable<CheckinEvent> events,
  MapWindow window, {
  int precision = Geohash.cityPrecision,
  DateTime? now,
}) {
  return aggregateByCell(
    filterByWindow(events, window, now: now),
    precision: precision,
  );
}
