// Widget tests for the author sheet (R4): the profile + npub, the friend
// toggle, "write a message" (opens the NIP-04 chat) and "show on map" from a
// world tile that carries a geohash.

import 'package:emosphere/core/geo/geohash.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/models/profile.dart';
import 'package:emosphere/core/nostr/nip19.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/feed_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_relay_service.dart';

/// Platform channel of flutter_secure_storage — mocked so `AppState.init`
/// does not wait forever on a missing plugin.
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

final String meHex = 'aa${'0' * 62}';
final String bobHex = 'bb${'0' * 62}';

/// Ana with a geohash (her tile must offer "show on map") and Bob without.
final String anaHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

final DateTime now = DateTime.now().toUtc();

CheckinEvent _checkin({
  required String id,
  required String pubkey,
  required Duration ago,
  Emotion emotion = Emotion.joy,
  int intensity = 3,
  String note = '',
  String? geohash,
}) {
  return CheckinEvent(
    id: id,
    pubkey: pubkey,
    emotion: emotion,
    intensity: intensity,
    note: note,
    geohash: geohash,
    createdAt: now.subtract(ago),
  );
}

List<CheckinEvent> _world() => <CheckinEvent>[
  _checkin(
    id: 'ck-ana',
    pubkey: anaHex,
    ago: const Duration(hours: 2),
    emotion: Emotion.calm,
    intensity: 3,
    note: 'Ranní klid',
    geohash: 'u2fkb',
  ),
  _checkin(
    id: 'ck-bob',
    pubkey: bobHex,
    ago: const Duration(minutes: 45),
    emotion: Emotion.sadness,
    intensity: 2,
    note: 'Unavený den',
  ),
];

Map<String, NostrProfile> _profiles() => <String, NostrProfile>{
  anaHex: NostrProfile(pubkey: anaHex, name: 'Áňa'),
  bobHex: NostrProfile(pubkey: bobHex, name: 'Bob Novák'),
};

/// Pumps the feed screen on top of a fake relay.
Future<(AppState, FakeRelayService)> _pumpFeed(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final service = FakeRelayService(
    world: _world(),
    profiles: _profiles(),
    pubkeyHex: meHex,
  );
  final app = AppState(service: service);
  addTearDown(app.dispose);
  await app.init(autoSync: false);
  await app.refresh();

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(body: FeedScreen(app: app)),
    ),
  );
  await tester.pumpAndSettle();
  return (app, service);
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

  testWidgets('the world tile opens the sheet with profile, npub and actions', (
    tester,
  ) async {
    await _pumpFeed(tester);

    await tester.tap(find.text('Unavený den'));
    await tester.pumpAndSettle();

    expect(find.text('Bob Novák'), findsOneWidget);
    expect(find.text(encodeNpub(bobHex)), findsOneWidget);
    expect(find.byKey(const Key('user_add_friend')), findsOneWidget);
    expect(find.byKey(const Key('user_message')), findsOneWidget);
    // Bob's check-in has no geohash → no "show on map".
    expect(find.byKey(const Key('user_show_on_map')), findsNothing);
    // The tapped check-in is repeated inside the sheet.
    expect(find.text('Unavený den'), findsNWidgets(2));
    expect(find.textContaining('2/5'), findsOneWidget);
  });

  testWidgets('adding a friend flips the button and updates the app', (
    tester,
  ) async {
    final (app, _) = await _pumpFeed(tester);

    await tester.tap(find.text('Unavený den'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user_add_friend')));
    await tester.pumpAndSettle();

    expect(app.friends, contains(bobHex));
    expect(find.byKey(const Key('user_add_friend')), findsNothing);
    expect(find.byKey(const Key('friends_remove')), findsOneWidget);
  });

  testWidgets('"write a message" opens the encrypted chat and sends', (
    tester,
  ) async {
    final (_, service) = await _pumpFeed(tester);

    await tester.tap(find.text('Unavený den'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('user_message')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dm_input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('dm_input')), 'Ahoj Bobe!');
    await tester.tap(find.byKey(const Key('dm_send')));
    await tester.pumpAndSettle();

    expect(service.publishedDms, hasLength(1));
    expect(service.publishedDms.single.recipientPubkey, bobHex);
    expect(service.publishedDms.single.text, 'Ahoj Bobe!');
    expect(find.text('Ahoj Bobe!'), findsOneWidget);
  });

  testWidgets('"show on map" asks the map to focus the coarse cell', (
    tester,
  ) async {
    final (app, _) = await _pumpFeed(tester);

    await tester.tap(find.text('Ranní klid'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('user_show_on_map')), findsOneWidget);
    await tester.tap(find.byKey(const Key('user_show_on_map')));
    await tester.pumpAndSettle();

    final request = app.mapFocusRequest;
    expect(request, isNotNull);
    final cell = Geohash.decode('u2fkb');
    expect(request!.point.latitude, closeTo(cell.latitude, 1e-9));
    expect(request.point.longitude, closeTo(cell.longitude, 1e-9));
  });
}
