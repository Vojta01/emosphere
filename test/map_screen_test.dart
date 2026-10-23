// Widget tests for the world map (card 3/7): heat cells aggregated from the
// check-in pool, the friend ring, the window switcher and the cell detail.

import 'dart:convert';

import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/models/profile.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/map_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:emosphere/widgets/heat_layer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_relay_service.dart';

/// Platform channel of flutter_secure_storage — mocked so `AppState.init`
/// does not wait forever on a missing plugin.
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// 1×1 transparent PNG: the tiles come from memory, no request leaves the test.
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

/// Prague, geohash precision 5 — the cell the fixture check-ins live in.
const String pragueCell = 'u2fkb';

/// Brno, precision 5 — a second cell, only visible in the 7-day window.
const String brnoCell = 'u2ezc';

final String meHex = 'aa${'0' * 62}';
final String friendHex = 'bb${'0' * 62}';
final String strangerHex = 'cc${'0' * 62}';

final DateTime now = DateTime.now().toUtc();

CheckinEvent _checkin({
  required String id,
  required String pubkey,
  required Duration ago,
  required Emotion emotion,
  required int intensity,
  String? geohash,
}) {
  return CheckinEvent(
    id: id,
    pubkey: pubkey,
    emotion: emotion,
    intensity: intensity,
    geohash: geohash,
    createdAt: now.subtract(ago),
  );
}

/// Four check-ins in the Prague cell (one of them mine, two of a friend) plus
/// one six-day-old check-in in Brno for the window switcher.
List<CheckinEvent> _world() => <CheckinEvent>[
  _checkin(
    id: 'ck-mine',
    pubkey: meHex,
    ago: const Duration(minutes: 50),
    emotion: Emotion.joy,
    intensity: 4,
    geohash: pragueCell,
  ),
  _checkin(
    id: 'ck-friend',
    pubkey: friendHex,
    ago: const Duration(minutes: 90),
    emotion: Emotion.joy,
    intensity: 5,
    geohash: pragueCell,
  ),
  _checkin(
    id: 'ck-stranger-1',
    pubkey: strangerHex,
    ago: const Duration(hours: 3),
    emotion: Emotion.calm,
    intensity: 3,
    geohash: pragueCell,
  ),
  _checkin(
    id: 'ck-stranger-2',
    pubkey: strangerHex,
    ago: const Duration(hours: 5),
    emotion: Emotion.sadness,
    intensity: 2,
    geohash: pragueCell,
  ),
  _checkin(
    id: 'ck-old',
    pubkey: strangerHex,
    ago: const Duration(days: 6),
    emotion: Emotion.anger,
    intensity: 5,
    geohash: brnoCell,
  ),
];

/// Pumps the map screen over a fake relay with an in-memory tile source.
Future<AppState> _pumpMap(
  WidgetTester tester, {
  List<String> friends = const <String>[],
  List<CheckinEvent>? checkins,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final world = checkins ?? _world();

  final service = FakeRelayService(
    mine: world.isEmpty ? const <CheckinEvent>[] : <CheckinEvent>[world.first],
    world: world,
    profiles: <String, NostrProfile>{
      friendHex: NostrProfile(pubkey: friendHex, name: 'Áňa'),
    },
    pubkeyHex: meHex,
  );
  final app = AppState(service: service);
  addTearDown(app.dispose);
  await app.init(autoSync: false);
  for (final friend in friends) {
    app.addFriend(friend);
  }
  await app.refresh();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: MapScreen(
          app: app,
          tileProvider: _MemoryTileProvider(MemoryImage(_tileBytes)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

/// Taps the centre of the first heat cell.
///
/// flutter_map holds a tap back until its double-tap delay elapsed, so the fake
/// clock has to move before `onTap` reaches the screen.
Future<void> _tapCell(WidgetTester tester) async {
  await tester.tapAt(_cellOffset(tester));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

/// Screen offset of the centre of the first heat cell.
Offset _cellOffset(WidgetTester tester) {
  final mapTopLeft = tester.getTopLeft(find.byType(FlutterMap));
  final camera = MapCamera.of(tester.element(find.byType(HeatLayer)));
  final cell = tester.widget<HeatLayer>(find.byType(HeatLayer)).cells.first;
  return mapTopLeft +
      camera.latLngToScreenOffset(
        LatLng(cell.center.latitude, cell.center.longitude),
      );
}

/// Taps the timeline slider at [fraction] of its width (0 = window start,
/// 1 = now) and lets the map rebuild.
Future<void> _scrubTo(WidgetTester tester, double fraction) async {
  final slider = tester.getRect(find.byKey(const Key('map_timeline')));
  await tester.tapAt(
    Offset(slider.left + slider.width * fraction, slider.center.dy),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('aggregates the check-ins of the last 24 hours into one cell', (
    tester,
  ) async {
    await _pumpMap(tester);

    expect(find.text('1 buňka'), findsOneWidget);
    expect(find.byType(HeatLayer), findsOneWidget);
    expect(find.byKey(const Key('map_window_switcher')), findsOneWidget);
    // The OSM credit stays visible on the map.
    expect(find.byKey(const Key('map_attribution')), findsOneWidget);
    // The legend explains all eight emotions.
    for (final emotion in Emotion.values) {
      expect(find.text(emotion.label('cs')), findsWidgets);
    }
  });

  testWidgets('shows the empty state when nothing was shared', (tester) async {
    await _pumpMap(tester, checkins: const <CheckinEvent>[]);

    expect(find.text('V tomto okně zatím nikdo nic nesdílel.'), findsOneWidget);
    expect(find.byType(HeatLayer), findsNothing);
    // The legend and the window switcher stay visible without data.
    expect(find.text('Radost'), findsOneWidget);
    expect(find.byKey(const Key('map_window_switcher')), findsOneWidget);
  });

  testWidgets('rings the cells that hold a friend check-in', (tester) async {
    await _pumpMap(tester, friends: <String>[friendHex]);

    final layer = tester.widget<HeatLayer>(find.byType(HeatLayer));
    // The ring sits on the cell that holds the friend check-in — the cell
    // geohash is a prefix of the g5 geohash the fixture used.
    final ringCell = layer.friendCells.single;
    expect(pragueCell, startsWith(ringCell));
    expect(find.text('kroužek = check-in přítele'), findsOneWidget);
  });

  testWidgets('no ring without a friend', (tester) async {
    await _pumpMap(tester);

    final layer = tester.widget<HeatLayer>(find.byType(HeatLayer));
    expect(layer.friendCells, isEmpty);
    expect(find.text('kroužek = check-in přítele'), findsNothing);
  });

  testWidgets('tapping a cell opens the emotion breakdown', (tester) async {
    await _pumpMap(tester, friends: <String>[friendHex]);

    await _tapCell(tester);

    expect(find.text('Rozpad emocí'), findsOneWidget);
    expect(find.byKey(const Key('map_detail_count')), findsOneWidget);
    expect(find.text('4 check-iny'), findsOneWidget);
    // Joy carries the highest intensity weight, so it leads the breakdown.
    expect(find.text('Radost'), findsWidgets);
    expect(find.text('Klid'), findsWidgets);
    expect(find.text('Smutek'), findsWidgets);
    // The cell holds a friend's check-in.
    expect(find.text('Je tu i někdo z tvých blízkých'), findsOneWidget);
  });

  testWidgets('the window switcher changes what the map aggregates', (
    tester,
  ) async {
    await _pumpMap(tester);

    // 24 h: only the Prague cell.
    expect(find.text('1 buňka'), findsOneWidget);

    await tester.tap(find.text('7 dní'));
    await tester.pumpAndSettle();
    expect(find.text('2 buňky'), findsOneWidget);

    await tester.tap(find.text('1 h'));
    await tester.pumpAndSettle();
    expect(find.text('1 buňka'), findsOneWidget);

    // Only my own check-in is inside the last hour.
    await _tapCell(tester);
    expect(find.text('1 check-in'), findsOneWidget);
  });

  testWidgets('recentring moves the camera to my last check-in', (
    tester,
  ) async {
    await _pumpMap(tester);

    await tester.tap(find.text('7 dní'));
    await tester.pumpAndSettle();

    final camera = MapCamera.of(
      tester.element(find.byType(HeatLayer)),
    );
    await tester.tap(find.byKey(const Key('map_recenter')));
    await tester.pumpAndSettle();
    final moved = MapCamera.of(
      tester.element(find.byType(HeatLayer)),
    );
    expect(moved.zoom, greaterThan(camera.zoom));
  });

  testWidgets('shows the time machine bar with the replay chips', (
    tester,
  ) async {
    await _pumpMap(tester);

    expect(find.byKey(const Key('map_play')), findsOneWidget);
    expect(find.byKey(const Key('map_timeline')), findsOneWidget);
    expect(find.text('Naživo'), findsOneWidget);
    // Replay window chips (R9: 1 h / 6 h / 24 h; 6 h pre-selected).
    for (final key in const ['machine_1h', 'machine_6h', 'machine_24h']) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    final six = tester.widget<ChoiceChip>(
      find.byKey(const Key('machine_6h')),
    );
    expect(six.selected, isTrue);
    // "Teď" appears only after leaving live mode.
    expect(find.byKey(const Key('map_live_now')), findsNothing);
  });

  testWidgets('scrubbing into the past freezes the map; Teď returns live', (
    tester,
  ) async {
    await _pumpMap(tester);

    await _scrubTo(tester, 0.05);

    // Near the start of the 24 h axis with the default 6 h window there is
    // nothing to show — and the live empty state must not claim otherwise.
    expect(find.text('Naživo'), findsNothing);
    expect(find.byKey(const Key('map_live_now')), findsOneWidget);
    expect(find.byType(HeatLayer), findsNothing);
    expect(find.text('V tomto okně zatím nikdo nic nesdílel.'), findsNothing);

    await tester.tap(find.byKey(const Key('map_live_now')));
    await tester.pumpAndSettle();
    expect(find.text('Naživo'), findsOneWidget);
    expect(find.byType(HeatLayer), findsOneWidget);
  });

  testWidgets('play replays the window and returns to live', (tester) async {
    await _pumpMap(tester);

    await tester.tap(find.byKey(const Key('map_play')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
    expect(find.text('Naživo'), findsNothing);

    await tester.pump(const Duration(seconds: 9));
    await tester.pump();
    expect(find.text('Naživo'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.byType(HeatLayer), findsOneWidget);
  });

  testWidgets('tapping the map pauses the replay in the past', (tester) async {
    await _pumpMap(tester);

    await tester.tap(find.byKey(const Key('map_play')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('Naživo'), findsNothing);
    expect(find.byKey(const Key('map_live_now')), findsOneWidget);
  });

  testWidgets('the replay window chips change what the past shows', (
    tester,
  ) async {
    // Ages chosen so the 1 h / 6 h / 24 h windows differ by whole check-ins.
    final events = <CheckinEvent>[
      _checkin(
        id: 'ck-2h',
        pubkey: strangerHex,
        ago: const Duration(hours: 2),
        emotion: Emotion.joy,
        intensity: 3,
        geohash: pragueCell,
      ),
      _checkin(
        id: 'ck-8h',
        pubkey: strangerHex,
        ago: const Duration(hours: 8),
        emotion: Emotion.calm,
        intensity: 3,
        geohash: pragueCell,
      ),
      _checkin(
        id: 'ck-20h',
        pubkey: strangerHex,
        ago: const Duration(hours: 20),
        emotion: Emotion.anger,
        intensity: 3,
        geohash: pragueCell,
      ),
    ];
    await _pumpMap(tester, checkins: events);

    await _scrubTo(tester, 0.75);

    HeatLayer layer() => tester.widget<HeatLayer>(find.byType(HeatLayer));
    // T ≈ now − 6 h; the default 6 h window holds just the 8 h old check-in.
    expect(layer().cells.first.count, 1);

    await tester.tap(find.byKey(const Key('machine_1h')));
    await tester.pumpAndSettle();
    expect(find.byType(HeatLayer), findsNothing);

    await tester.tap(find.byKey(const Key('machine_24h')));
    await tester.pumpAndSettle();
    expect(layer().cells.first.count, 2);
  });
}
