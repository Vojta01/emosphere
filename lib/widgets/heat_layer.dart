// Smooth heat layer for the world mood map (R8).
//
// One soft blob per aggregated cell instead of the old hard-edged circles:
// the colour fades to fully transparent towards the edge and the blobs blend
// additively (BlendMode.plus), so neighbouring cells melt into a continuous
// heat layer — the look approved in the R8 mockup.
//
// Rendering only: the cell colour comes from the R1 OKLab blend, the radius
// and opacity from heat.dart, and taps keep resolving through cellAt() in
// heat.dart — this layer never touches the data.

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/geo/aggregate.dart';
import '../core/geo/heat.dart';

/// Smooth heat layer: one soft additive blob per cell.
class HeatLayer extends StatelessWidget {
  const HeatLayer({super.key, required this.cells, required this.friendCells});

  /// Aggregated cells of the current window (busiest first).
  final List<CellAggregate> cells;

  /// Geohashes of the cells that hold a friend's check-in (white ring).
  final Set<String> friendCells;

  @override
  Widget build(BuildContext context) {
    return MobileLayerTransformer(
      child: CustomPaint(
        painter: HeatPainter(
          cells: cells,
          friendCells: friendCells,
          camera: MapCamera.of(context),
        ),
      ),
    );
  }
}

/// Paints one radial-gradient blob per cell, blended additively.
class HeatPainter extends CustomPainter {
  HeatPainter({
    required this.cells,
    required this.friendCells,
    required this.camera,
  });

  /// Cells to draw, sorted by check-in count (descending).
  final List<CellAggregate> cells;

  /// Geohashes that get the friend ring.
  final Set<String> friendCells;

  /// Camera of the current frame (screen projection + world width).
  final MapCamera camera;

  /// Blob radius as a multiple of the cell radius: slightly over the cell so
  /// neighbouring blobs overlap even when their cells only touch at the edge.
  static const double _coreScale = 1.08;

  /// Wide, faint halo around the core — lets distant blobs bleed together.
  static const double _haloScale = 2.15;

  /// Halo alpha relative to the core alpha.
  static const double _haloAlpha = 0.25;

  static const Distance _distance = Distance();

  @override
  void paint(Canvas canvas, Size size) {
    if (cells.isEmpty) {
      return;
    }
    canvas.clipRect(Offset.zero & size);

    // The cells are sorted by count, so the first one is the busiest.
    final maxCount = cells.first.count;
    final worldWidth = camera.getWorldWidthAtZoom();
    final rings = <(Offset, double)>[];

    for (final cell in cells) {
      if (cell.dominant == null) {
        continue;
      }
      final point = LatLng(cell.center.latitude, cell.center.longitude);
      final radiusPx = _metersToPixels(point, heatRadiusMeters(cell.geohash));
      // The mockup's tonemapped cores sit around 0.35–0.9, brighter than the
      // raw logarithmic opacity — single check-ins stay clearly visible.
      final coreAlpha = (heatOpacity(cell.count, maxCount: maxCount) * 1.4)
          .clamp(0.0, 0.9);
      final color = cell.blended;
      final base = camera.getOffsetFromOrigin(point);
      final reach = radiusPx * _haloScale;

      // Draw across the wrapped worlds (the map repeats horizontally).
      for (final shift in <double>[0, worldWidth, -worldWidth]) {
        final center = base + Offset(shift, 0);
        if (!Rect.fromCircle(
          center: center,
          radius: reach,
        ).overlaps(Offset.zero & size)) {
          continue;
        }
        _paintBlob(canvas, center, radiusPx * _coreScale, color, coreAlpha);
        _paintBlob(
          canvas,
          center,
          radiusPx * _haloScale,
          color,
          coreAlpha * _haloAlpha,
        );
        if (friendCells.contains(cell.geohash)) {
          rings.add((center, radiusPx * _coreScale));
        }
      }
    }

    // The friend ring sits on top of the blobs, outside the additive mix.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Colors.white.withValues(alpha: 0.85);
    for (final (center, radius) in rings) {
      canvas.drawCircle(center, radius, ringPaint);
    }
  }

  /// Paints one soft blob: opaque core fading to transparent at [radius].
  void _paintBlob(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final paint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: alpha),
          color.withValues(alpha: alpha * 0.45),
          color.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);
  }

  /// Screen pixels that one metre spans at [point].
  ///
  /// Same maths as flutter_map's own circle layer: project the point and a
  /// point one metre south of it, then measure the distance.
  double _metersToPixels(LatLng point, double meters) {
    final here = camera.getOffsetFromOrigin(point);
    final south = camera.getOffsetFromOrigin(
      _distance.offset(point, meters, 180),
    );
    return (here - south).distance;
  }

  @override
  bool shouldRepaint(HeatPainter oldDelegate) =>
      cells != oldDelegate.cells ||
      friendCells != oldDelegate.friendCells ||
      camera != oldDelegate.camera;
}
