// Widget tests for the world map (card 3/7): heat cells aggregated from the
// check-in pool, the friend ring, the window switcher and the cell detail.

import 'dart:convert';

import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/models/profile.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/map_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
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
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final service = FakeRelayService(
    mine: <CheckinEvent>[_world().first],
    world: _world(),
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
  final camera = MapCamera.of(tester.element(find.byType(CircleLayer<Object>)));
  final circle = tester
      .widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>))
      .circles
      .first;
  return mapTopLeft + camera.latLngToScreenOffset(circle.point);
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
    expect(find.byKey(const Key('map_window_switcher')), findsOneWidget);
    // The OSM credit stays visible on the map.
    expect(find.byKey(const Key('map_attribution')), findsOneWidget);
    // The legend explains all eight emotions.
    for (final emotion in Emotion.values) {
      expect(find.text(emotion.label('cs')), findsWidgets);
    }
  });

  testWidgets('rings the cells that hold a friend check-in', (tester) async {
    await _pumpMap(tester, friends: <String>[friendHex]);

    final circles = tester
        .widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>))
        .circles;
    final rings = circles.where(
      (circle) => circle.borderColor == Colors.white.withValues(alpha: 0.85),
    );
    expect(rings, hasLength(1));
    expect(find.text('kroužek = check-in přítele'), findsOneWidget);
  });

  testWidgets('no ring without a friend', (tester) async {
    await _pumpMap(tester);

    final circles = tester
        .widget<CircleLayer<Object>>(find.byType(CircleLayer<Object>))
        .circles;
    expect(
      circles.where(
        (circle) => circle.borderColor == Colors.white.withValues(alpha: 0.85),
      ),
      isEmpty,
    );
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
      tester.element(find.byType(CircleLayer<Object>)),
    );
    await tester.tap(find.byKey(const Key('map_recenter')));
    await tester.pumpAndSettle();
    final moved = MapCamera.of(
      tester.element(find.byType(CircleLayer<Object>)),
    );
    expect(moved.zoom, greaterThan(camera.zoom));
  });
}
