// Tests for the smooth heat layer (R8): painter repaint semantics and a real
// render of the additive blobs onto the map canvas.
//
// Set HEAT_RENDER_OUT to a file path to also dump the rendered PNG (used to
// eyeball the style next to the approved R8 mockup).

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:emosphere/core/geo/aggregate.dart';
import 'package:emosphere/core/geo/geohash.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/widgets/heat_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

/// 1×1 transparent PNG — the tiles come from memory, no request leaves the test.
final _tileBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/q842iQAAAABJRU5ErkJggg==',
);

/// Tile source that paints a constant pixel instead of talking to a tile server.
class _MemoryTileProvider extends TileProvider {
  _MemoryTileProvider(this._image);

  final MemoryImage _image;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _image;
}

/// Six check-ins around Prague at geohash precision 6 (area cells).
List<CellAggregate> _cells() {
  final base = DateTime.utc(2026, 10, 22, 12);
  final samples = <(double, double, Emotion, int)>[
    (50.0755, 14.4378, Emotion.joy, 5),
    (50.0770, 14.4390, Emotion.joy, 2),
    (50.0730, 14.4330, Emotion.calm, 3),
    (50.0720, 14.4410, Emotion.love, 2),
    (50.0790, 14.4420, Emotion.anger, 4),
    (50.0745, 14.4460, Emotion.sadness, 3),
  ];
  final events = <CheckinEvent>[
    for (final (index, (lat, lon, emotion, intensity)) in samples.indexed)
      CheckinEvent(
        id: 'ck-$index',
        pubkey: 'aa${index.toString().padLeft(2, '0')}${'0' * 60}',
        emotion: emotion,
        intensity: intensity,
        geohash: Geohash.encode(lat, lon, precision: Geohash.areaPrecision),
        createdAt: base,
      ),
  ];
  return aggregateByCell(events, precision: Geohash.areaPrecision);
}

void main() {
  MapCamera cameraAt(double zoom) => MapCamera.initialCamera(
    MapOptions(
      initialCenter: const LatLng(50.0755, 14.4378),
      initialZoom: zoom,
    ),
  );

  group('HeatPainter', () {
    test('repaints when the cells or the camera change', () {
      final cells = _cells();
      final camera = cameraAt(13);
      final base = HeatPainter(
        cells: cells,
        friendCells: const <String>{},
        camera: camera,
      );

      // Same instances: nothing to repaint.
      expect(
        base.shouldRepaint(
          HeatPainter(
            cells: cells,
            friendCells: const <String>{},
            camera: camera,
          ),
        ),
        isFalse,
      );
      // A fresh aggregation (new list identity) repaints.
      expect(
        base.shouldRepaint(
          HeatPainter(
            cells: _cells(),
            friendCells: const <String>{},
            camera: camera,
          ),
        ),
        isTrue,
      );
      // A new friend set repaints.
      expect(
        base.shouldRepaint(
          HeatPainter(
            cells: cells,
            friendCells: const <String>{'u2fkbe'},
            camera: camera,
          ),
        ),
        isTrue,
      );
      // A camera change (pan/zoom) repaints.
      expect(
        base.shouldRepaint(
          HeatPainter(
            cells: cells,
            friendCells: const <String>{},
            camera: cameraAt(14),
          ),
        ),
        isTrue,
      );
    });
  });

  testWidgets('paints additive blobs onto the map', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420, 420));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final cells = _cells();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(50.0755, 14.4378),
              initialZoom: 13,
              backgroundColor: const Color(0xFF0E1220),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.emosphere',
                tileProvider: _MemoryTileProvider(MemoryImage(_tileBytes)),
              ),
              HeatLayer(
                cells: cells,
                friendCells: <String>{cells.first.geohash},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byType(FlutterMap),
    );
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final raw = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    final bytes = raw.buffer.asUint8List();

    // The dark background (#0E1220 ≈ 14+18+32 = 64) stays dark; the blobs add
    // colour on top, so a healthy share of pixels must be brighter than it.
    var bright = 0;
    for (var i = 0; i + 3 < bytes.length; i += 4) {
      if (bytes[i] + bytes[i + 1] + bytes[i + 2] > 120) {
        bright++;
      }
    }
    expect(
      bright,
      greaterThan(300),
      reason: 'the blobs should cover a part of the map canvas',
    );

    final out = Platform.environment['HEAT_RENDER_OUT'];
    if (out != null && out.isNotEmpty) {
      final png = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      File(out).writeAsBytesSync(png.buffer.asUint8List());
    }
  });
}
