// Map screen — the world mood map (card 3).
//
// flutter_map with OpenStreetMap tiles (attribution bottom right, darkened with
// the package's invert + hue-rotate filter so the emotion colours stay the only
// bright thing on screen). The heat layer (R8) is aggregated from the check-in
// pool: one soft additive blob per cell — colour = blended mix of the cell's
// check-ins (R1), radius = the geohash cell size, glow = the number of
// check-ins. Cells that hold a friend's check-in get a white ring. Tapping a
// cell opens the emotion breakdown.
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
import '../core/models/checkin.dart';
import '../core/models/emotion.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/heat_layer.dart';
import '../widgets/timeline_bar.dart';

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

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  /// Fallback view when there is no check-in and no cell to centre on.
  static const LatLng _fallbackCenter = LatLng(50.0755, 14.4378);

  /// Zoom of the first frame — the whole world with a hint of Europe.
  static const double _initialZoom = 3;

  final MapController _controller = MapController();

  MapWindow _window = MapWindow.hours24;
  int _precision = precisionForZoom(_initialZoom);
  bool _showHint = true;

  // ---------------------------------------------------------------------
  // Time machine (R9)
  // ---------------------------------------------------------------------

  /// Length of one replay: the machine scrubs the whole selected window in
  /// this time (R9 decision: ~8 s).
  static const Duration _replayDuration = Duration(seconds: 8);

  /// Replay driver: 0 = start of the selected window, 1 = now.
  late final AnimationController _playback =
      AnimationController(vsync: this, duration: _replayDuration)
        ..addListener(_onReplayTick);

  /// Slider position 0..1; `null` in live mode (the whole window is shown).
  double? _scrub;

  /// Frozen "now" of the current scrub session — the map must not move under
  /// the user's hands while they replay the past (R9: time is frozen).
  DateTime? _anchor;

  /// Replay window length picked with the chips (1 h / 6 h / 24 h).
  Duration _machineWindow = const Duration(hours: 6);

  /// Id of the last "show on map" request handled (R4).
  int _lastFocusId = 0;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    _playback.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Handles one-shot "show on map" requests (R4).
  void _onAppChanged() {
    final request = widget.app.mapFocusRequest;
    if (request == null || request.id == _lastFocusId) {
      return;
    }
    _lastFocusId = request.id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final point = request.point;
      _controller.move(LatLng(point.latitude, point.longitude), 12);
      widget.app.clearMapFocus(request.id);
    });
  }

  // ---------------------------------------------------------------------
  // Time machine (R9)
  // ---------------------------------------------------------------------

  /// Instant the time machine points at; `null` when live.
  ///
  /// The scrub axis spans the selected window: 0 = window start, 1 = now.
  DateTime? _scrubEnd() {
    final scrub = _scrub;
    final anchor = _anchor;
    if (scrub == null || anchor == null) {
      return null;
    }
    return anchor.subtract(_window.duration * (1 - scrub));
  }

  void _onReplayTick() {
    if (!mounted) {
      return;
    }
    setState(() {
      // A finished replay drops back into live mode (R9: play -> now).
      if (_playback.status == AnimationStatus.completed) {
        _scrub = null;
        _anchor = null;
      } else {
        _scrub = _playback.value;
      }
    });
  }

  /// Play/pause of the replay. From live it always replays the whole window;
  /// after a pause it resumes from the scrubbed instant.
  void _togglePlay() {
    if (_playback.isAnimating) {
      _playback.stop();
      setState(() {});
      return;
    }
    if (_scrub == null) {
      _anchor = DateTime.now().toUtc();
      _playback.value = 0;
    } else {
      _playback.value = _scrub!.clamp(0.0, 1.0);
    }
    _playback.forward();
    setState(() {});
  }

  /// Slider changes pause the replay and scrub to the touched instant.
  void _onScrub(double value) {
    _playback.stop();
    if (value >= 0.999) {
      _goLive();
      return;
    }
    setState(() {
      _anchor ??= DateTime.now().toUtc();
      _scrub = value;
    });
  }

  /// Returns to live mode (the R9 "Teď" button).
  void _goLive() {
    _playback.stop();
    setState(() {
      _scrub = null;
      _anchor = null;
    });
  }

  /// R9: pauses the replay where it stands (a tap anywhere on the map).
  void _pauseReplay() {
    _playback.stop();
    setState(() {});
  }

  // ---------------------------------------------------------------------
  // Map callbacks
  // ---------------------------------------------------------------------

  /// Re-aggregates only when the zoom band changes (not on every frame).
  ///
  /// The initial camera fit runs inside the first build, so the new precision
  /// is stored right away and the rebuild is deferred to the next frame.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    final precision = precisionForZoom(camera.zoom);
    if (precision == _precision) {
      return;
    }
    _precision = precision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onMapTap(
    List<CellAggregate> cells,
    Set<String> friendCells,
    LatLng point,
  ) {
    // R9: a tap anywhere pauses the replay and stays in the past (the pause
    // layer above the map normally catches this before flutter_map sees it).
    if (_playback.isAnimating) {
      _pauseReplay();
      return;
    }
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
      // Coarse (legacy) hashes zoom out more; the newest precision 6
      // cells zoom in the closest.
      final double zoom;
      if (hash.length <= 4) {
        zoom = 6;
      } else if (hash.length == Geohash.cityPrecision) {
        zoom = 10;
      } else {
        zoom = 12;
      }
      _controller.move(LatLng(center.latitude, center.longitude), zoom);
      return;
    }
    if (cells.isNotEmpty) {
      final center = cells.first.center;
      _controller.move(LatLng(center.latitude, center.longitude), 6);
      return;
    }
    _controller.move(_fallbackCenter, _initialZoom);
  }

  LatLng _initialCenter(List<LatLng> points, List<CellAggregate> cells) {
    final mine = sortByNewest(widget.app.myCheckins);
    final hash = mine.isEmpty ? null : mine.first.geohash;
    if (hash != null && hash.isNotEmpty) {
      final center = Geohash.decode(hash);
      return LatLng(center.latitude, center.longitude);
    }
    if (points.isNotEmpty) {
      return points.first;
    }
    if (cells.isNotEmpty) {
      final center = cells.first.center;
      return LatLng(center.latitude, center.longitude);
    }
    return _fallbackCenter;
  }

  /// Locations of [events] that carry a geohash, newest first.
  ///
  /// The first camera is fitted to these raw points instead of the aggregated
  /// cells: the aggregation precision depends on the zoom, which the fit itself
  /// determines, so fitting cells would open the map on a continent-sized cell
  /// centre.
  List<LatLng> _checkinPoints(List<CheckinEvent> events) {
    final points = <LatLng>[];
    for (final event in events) {
      final geohash = event.geohash;
      if (geohash == null || geohash.isEmpty) {
        continue;
      }
      final point = Geohash.decode(geohash);
      points.add(LatLng(point.latitude, point.longitude));
    }
    return points;
  }

  /// First camera: shows every check-in location of the current window.
  ///
  /// Returns `null` when no check-in carries a location — the map then opens on
  /// [_initialCenter] at [_initialZoom]. [maxZoom] keeps a single point from
  /// filling the screen with a degenerate (zero-area) fit.
  CameraFit? _cameraFit(List<LatLng> points) {
    if (points.isEmpty) {
      return null;
    }
    return CameraFit.coordinates(
      coordinates: points,
      padding: const EdgeInsets.fromLTRB(56, 186, 56, 208),
      maxZoom: 6,
      minZoom: 1.5,
    );
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
          final scrubEnd = _scrubEnd();
          // Live = today's whole-window view. Scrubbing replays the past
          // through the sliding window of the picked length (R9, variant B).
          final windowed = scrubEnd == null
              ? filterByWindow(pool, _window)
              : filterBySlidingWindow(
                  pool,
                  end: scrubEnd,
                  duration: _machineWindow,
                );
          final cells = aggregateByCell(windowed, precision: _precision);
          final friendCells = friendCellHashes(
            windowed,
            app.friends,
            precision: _precision,
          );
          final points = _checkinPoints(windowed);
          return Stack(
            children: [
              Positioned.fill(child: _map(cells, friendCells, points)),
              // While the replay runs, the first tap anywhere pauses it
              // (R9). The layer sits below the control cards so their
              // buttons stay live, and fires instantly — no flutter_map
              // double-tap delay.
              if (_playback.isAnimating)
                Positioned.fill(
                  child: GestureDetector(
                    key: const Key('map_replay_pause_layer'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _pauseReplay,
                  ),
                ),
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: _overlay(s, cells, friendCells, scrubEnd),
              ),
              // The live empty state is about "nobody shared yet"; an empty
              // map while scrubbing the past just shows the map.
              if (cells.isEmpty && scrubEnd == null)
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

  Widget _map(
    List<CellAggregate> cells,
    Set<String> friendCells,
    List<LatLng> points,
  ) {
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _initialCenter(points, cells),
        initialZoom: _initialZoom,
        initialCameraFit: _cameraFit(points),
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
          HeatLayer(cells: cells, friendCells: friendCells),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Overlays
  // ---------------------------------------------------------------------

  Widget _overlay(
    Strings s,
    List<CellAggregate> cells,
    Set<String> friendCells,
    DateTime? scrubEnd,
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
                    s.mapCellsCount(cells.length),
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
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
          child: TimelineBar(
            language: s.language,
            live: scrubEnd == null,
            fraction: _scrub ?? 1,
            playing: _playback.isAnimating,
            instant: scrubEnd,
            machineWindow: _machineWindow,
            onPlayPause: _togglePlay,
            onScrub: _onScrub,
            onLive: _goLive,
            onMachineWindow: (window) =>
                setState(() => _machineWindow = window),
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
    final accent = dominant == null ? AppTheme.accent : cell.blended;
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
