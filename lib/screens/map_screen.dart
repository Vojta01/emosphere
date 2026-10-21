// Map screen — the world mood map (card 3).
//
// flutter_map with OpenStreetMap tiles (attribution bottom right, darkened with
// the package's invert + hue-rotate filter so the emotion colours stay the only
// bright thing on screen). The heat layer is aggregated from the check-in pool:
// circle colour = dominant emotion of the cell, radius = the geohash cell size,
// opacity = the number of check-ins. Cells that hold a friend's check-in get a
// white ring. Tapping a cell opens the emotion breakdown.
//
// The geohash precision follows the camera zoom, so the map shows coarse cells
// from far away and city-sized cells up close.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/feed/feed_logic.dart';
import '../core/geo/aggregate.dart';
import '../core/geo/geohash.dart';
import '../core/geo/heat.dart';
import '../core/i18n/strings.dart';
import '../core/models/emotion.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// World mood map: OSM tiles plus the aggregated emotion heat layer.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.app, this.tileProvider});

  /// Application state (world and friend check-ins live here).
  final AppState app;

  /// Optional tile source. Widget tests inject an in-memory provider so no
  /// request leaves the test; the app itself uses the default network provider.
  final TileProvider? tileProvider;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  /// Fallback view when there is no check-in and no cell to centre on.
  static const LatLng _fallbackCenter = LatLng(50.0755, 14.4378);

  /// Zoom of the first frame — the whole world with a hint of Europe.
  static const double _initialZoom = 3;

  final MapController _controller = MapController();

  MapWindow _window = MapWindow.hours24;
  int _precision = precisionForZoom(_initialZoom);
  bool _showHint = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Map callbacks
  // ---------------------------------------------------------------------

  /// Re-aggregates only when the zoom band changes (not on every frame).
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final precision = precisionForZoom(camera.zoom);
    if (precision != _precision) {
      setState(() => _precision = precision);
    }
  }

  void _onMapTap(
    List<CellAggregate> cells,
    Set<String> friendCells,
    LatLng point,
  ) {
    final cell = cellAt(cells, GeoPoint(point.latitude, point.longitude));
    if (cell == null) {
      return;
    }
    HapticFeedback.selectionClick();
    _showCellDetail(cell, friendCells.contains(cell.geohash));
  }

  /// Moves the camera back to my last check-in, or to the newest cell.
  void _recenter(List<CellAggregate> cells) {
    final mine = sortByNewest(widget.app.myCheckins);
    final hash = mine.isEmpty ? null : mine.first.geohash;
    if (hash != null && hash.isNotEmpty) {
      final center = Geohash.decode(hash);
      _controller.move(
        LatLng(center.latitude, center.longitude),
        hash.length <= Geohash.areaPrecision ? 6 : 10,
      );
      return;
    }
    if (cells.isNotEmpty) {
      final center = cells.first.center;
      _controller.move(LatLng(center.latitude, center.longitude), 6);
      return;
    }
    _controller.move(_fallbackCenter, _initialZoom);
  }

  LatLng _initialCenter(List<CellAggregate> cells) {
    final mine = sortByNewest(widget.app.myCheckins);
    final hash = mine.isEmpty ? null : mine.first.geohash;
    if (hash != null && hash.isNotEmpty) {
      final center = Geohash.decode(hash);
      return LatLng(center.latitude, center.longitude);
    }
    if (cells.isNotEmpty) {
      final center = cells.first.center;
      return LatLng(center.latitude, center.longitude);
    }
    return _fallbackCenter;
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final s = Strings(widget.app.language);
          final app = widget.app;
          final pool = checkinPool(app.worldCheckins, app.friendCheckins);
          final windowed = filterByWindow(pool, _window);
          final cells = aggregateByCell(windowed, precision: _precision);
          final friendCells = friendCellHashes(
            windowed,
            app.friends,
            precision: _precision,
          );
          return Stack(
            children: [
              Positioned.fill(child: _map(cells, friendCells)),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _overlay(s, cells, friendCells),
              ),
              if (cells.isEmpty)
                Positioned.fill(child: Center(child: _emptyState(s))),
              Positioned(
                right: 12,
                bottom: 176,
                child: _recenterButton(s, cells),
              ),
              if (_showHint && cells.isNotEmpty)
                Positioned(left: 12, right: 76, bottom: 176, child: _hint(s)),
              // Required by the OSM tile usage policy.
              const Positioned(right: 12, bottom: 96, child: _OsmAttribution()),
            ],
          );
        },
      ),
    );
  }

  Widget _map(List<CellAggregate> cells, Set<String> friendCells) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _initialCenter(cells),
        initialZoom: _initialZoom,
        minZoom: 1.5,
        maxZoom: 18,
        backgroundColor: AppTheme.backgroundTop,
        // Rotation off: a mood map is always north up.
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onTap: (tapPosition, point) => _onMapTap(cells, friendCells, point),
        onPositionChanged: _onPositionChanged,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.emosphere',
          maxZoom: 19,
          tileProvider: widget.tileProvider,
          // Turns the light OSM basemap into a dark one (invert + hue rotate).
          tileBuilder: darkModeTileBuilder,
          // Offline / blocked tiles leave the dark background in place.
          errorTileCallback: (tile, error, stackTrace) {},
        ),
        if (cells.isNotEmpty)
          CircleLayer<Object>(circles: _heatCircles(cells, friendCells)),
      ],
    );
  }

  /// Heat circles: glow, colour fill and the friend ring, in paint order.
  List<CircleMarker<Object>> _heatCircles(
    List<CellAggregate> cells,
    Set<String> friendCells,
  ) {
    final maxCount = cells.isEmpty ? 1 : cells.first.count;
    final markers = <CircleMarker<Object>>[];
    for (final cell in cells) {
      final dominant = cell.dominant;
      if (dominant == null) {
        continue;
      }
      final point = LatLng(cell.center.latitude, cell.center.longitude);
      final radius = heatRadiusMeters(cell.geohash);
      final opacity = heatOpacity(cell.count, maxCount: maxCount);
      markers.add(
        CircleMarker<Object>(
          point: point,
          radius: radius * 1.55,
          useRadiusInMeter: true,
          color: dominant.color.withValues(alpha: opacity * 0.22),
        ),
      );
      markers.add(
        CircleMarker<Object>(
          point: point,
          radius: radius,
          useRadiusInMeter: true,
          color: dominant.color.withValues(alpha: opacity),
          borderColor: dominant.color.withValues(
            alpha: (opacity + 0.3).clamp(0.0, 1.0),
          ),
          borderStrokeWidth: 1.2,
        ),
      );
      if (friendCells.contains(cell.geohash)) {
        markers.add(
          CircleMarker<Object>(
            point: point,
            radius: radius * 1.12,
            useRadiusInMeter: true,
            color: Colors.transparent,
            borderColor: Colors.white.withValues(alpha: 0.85),
            borderStrokeWidth: 1.6,
          ),
        );
      }
    }
    return markers;
  }

  // ---------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------

  Widget _overlay(
    Strings s,
    List<CellAggregate> cells,
    Set<String> friendCells,
  ) {
    return Column(
      children: [
        GlassCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.tr('map'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    '${cells.length} ${s.tr('map.cells')}',
                    key: const Key('map_cell_count'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<MapWindow>(
                key: const Key('map_window_switcher'),
                showSelectedIcon: false,
                segments: [
                  for (final window in MapWindow.values)
                    ButtonSegment<MapWindow>(
                      value: window,
                      label: Text(window.label(s.language)),
                    ),
                ],
                selected: <MapWindow>{_window},
                onSelectionChanged: (selection) =>
                    setState(() => _window = selection.first),
                style: ButtonStyle(
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final emotion in Emotion.values)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: emotion.color,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          emotion.label(s.language),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: emotion.color,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              if (friendCells.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.tr('map.friendRing'),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _emptyState(Strings s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 34),
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.glassDecoration(radius: 20, opacity: 0.8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text(
            s.tr('mapEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recenterButton(Strings s, List<CellAggregate> cells) {
    return Tooltip(
      message: s.tr('map.recenter'),
      child: Material(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.92),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('map_recenter'),
          customBorder: const CircleBorder(),
          onTap: () => _recenter(cells),
          child: const Padding(
            padding: EdgeInsets.all(11),
            child: Icon(Icons.my_location, size: 20, color: AppTheme.accent),
          ),
        ),
      ),
    );
  }

  Widget _hint(Strings s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: AppTheme.glassDecoration(radius: 16, opacity: 0.82),
      child: Row(
        children: [
          const Icon(Icons.touch_app, size: 15, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              s.tr('map.hint'),
              style: TextStyle(
                fontSize: 11,
                height: 1.3,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
          IconButton(
            key: const Key('map_hint_close'),
            tooltip: s.tr('close'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 15),
            color: Colors.white.withValues(alpha: 0.45),
            onPressed: () => setState(() => _showHint = false),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Cell detail
  // ---------------------------------------------------------------------

  /// Bottom sheet with the emotion breakdown of one heat cell.
  Future<void> _showCellDetail(CellAggregate cell, bool hasFriends) async {
    final s = Strings(widget.app.language);
    final dominant = cell.dominant;
    final accent = dominant?.color ?? AppTheme.accent;
    final ranked =
        <Emotion>[
          for (final emotion in Emotion.values)
            if ((cell.counts[emotion] ?? 0) > 0) emotion,
        ]..sort((a, b) {
          final byCount = (cell.counts[b] ?? 0).compareTo(cell.counts[a] ?? 0);
          if (byCount != 0) {
            return byCount;
          }
          return (cell.weights[b] ?? 0).compareTo(cell.weights[a] ?? 0);
        });
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: AppTheme.glassDecoration(
            radius: 26,
            tint: AppTheme.surfaceHigh,
            opacity: 0.98,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                      border: Border.all(color: accent.withValues(alpha: 0.55)),
                    ),
                    child: Text(
                      dominant?.emoji ?? '📍',
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dominant?.label(s.language) ?? s.tr('cellDetail'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          cell.geohash,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    s.checkinsCount(cell.count),
                    key: const Key('map_detail_count'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              if (hasFriends) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.tr('map.friendsHere'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                s.tr('map.breakdown'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 10),
              for (final emotion in ranked)
                _breakdownRow(s, emotion, cell, share: cell.shareOf(emotion)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdownRow(
    Strings s,
    Emotion emotion,
    CellAggregate cell, {
    required double share,
  }) {
    final count = cell.counts[emotion] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emotion.color,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  emotion.label(s.language),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: emotion.color,
                  ),
                ),
              ),
              Text(
                '${(share * 100).round()} %',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$count ×',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                FractionallySizedBox(
                  widthFactor: share.clamp(0.02, 1.0),
                  child: Container(height: 6, color: emotion.color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// OSM tile credit.
///
/// A compact chip instead of [SimpleAttributionWidget]: the built-in widget
/// cannot wrap its text, so long credits overflow on narrow screens.
class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        key: const Key('map_attribution'),
        style: TextStyle(
          fontSize: 8.5,
          color: Colors.white.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
