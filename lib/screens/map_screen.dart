// Map screen — mood heat cells.
//
// Minimal scaffold for the core (card 1): window switcher (1 h / 24 h / 7 d),
// colour legend and the aggregated per-cell breakdown. Card 3 replaces the
// list with flutter_map + OSM tiles and the heat layer on top of the same
// aggregation helpers.

import 'package:flutter/material.dart';

import '../core/geo/aggregate.dart';
import '../core/geo/geohash.dart';
import '../core/i18n/strings.dart';
import '../core/models/emotion.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// World mood map: heat cells aggregated from the world feed.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.app});

  /// Application state (world check-ins live here).
  final AppState app;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapWindow _window = MapWindow.hours24;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final s = Strings(widget.app.language);
          final cells = aggregateWindow(
            widget.app.worldCheckins,
            _window,
            precision: Geohash.areaPrecision,
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.tr('map'),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _windowSwitcher(s),
                ],
              ),
              const SizedBox(height: 14),
              _legend(s),
              const SizedBox(height: 14),
              if (cells.isEmpty)
                _empty(s)
              else
                for (final cell in cells)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _cellTile(cell, s),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _windowSwitcher(Strings s) {
    return SegmentedButton<MapWindow>(
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
    );
  }

  Widget _legend(Strings s) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final emotion in Emotion.values)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: emotion.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: emotion.color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emotion.color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  emotion.label(s.language),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: emotion.color,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _empty(Strings s) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          const Text('🗺️', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 14),
          Text(
            s.tr('mapEmpty'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cellTile(CellAggregate cell, Strings s) {
    final dominant = cell.dominant;
    final color = dominant?.color ?? AppTheme.accent;
    return GlassCard(
      radius: 18,
      glowColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dominant?.emoji ?? '📍',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cell.geohash,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      dominant?.label(s.language) ?? '',
                      style: TextStyle(fontSize: 12, color: color),
                    ),
                  ],
                ),
              ),
              Text(
                '${cell.count} ${s.tr('checkInsShort')}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                for (final emotion in Emotion.values)
                  if ((cell.weights[emotion] ?? 0) > 0)
                    Expanded(
                      flex: ((cell.shareOf(emotion) * 1000).round()).clamp(
                        1,
                        1000,
                      ),
                      child: Container(
                        height: 8,
                        color: emotion.color.withValues(alpha: 0.9),
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
