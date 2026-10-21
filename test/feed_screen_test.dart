// Widget tests for the feed screen (card 3/7): the "my close ones" section
// (kind 0 names, latest check-in per friend), the world stream, and the
// add / remove friend flows.

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

/// Published NIP-19 example key, used here as friend #1 (added as an npub).
const String friendNpub =
    'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
const String friendHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

/// Friend without any check-in and without metadata.
final String quietFriendHex = 'dd${'0' * 62}';

/// The signed-in user, and two more authors in the world stream.
final String meHex = 'aa${'0' * 62}';
final String bobHex = 'bb${'0' * 62}';
final String strangerHex = 'cc${'0' * 62}';

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

/// The world stream: my own check-in plus friends and a stranger.
List<CheckinEvent> _world() => <CheckinEvent>[
  _checkin(
    id: 'ck-mine',
    pubkey: meHex,
    ago: const Duration(minutes: 30),
    emotion: Emotion.joy,
    intensity: 4,
    note: 'Moje vlastní poznámka',
    geohash: 'u2fkb',
  ),
  _checkin(
    id: 'ck-ana',
    pubkey: friendHex,
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
  _checkin(
    id: 'ck-stranger',
    pubkey: strangerHex,
    ago: const Duration(minutes: 10),
    emotion: Emotion.anger,
    intensity: 5,
    note: 'Někdo úplně jiný',
  ),
];

Map<String, NostrProfile> _profiles() => <String, NostrProfile>{
  friendHex: NostrProfile(pubkey: friendHex, name: 'Áňa'),
  bobHex: NostrProfile(pubkey: bobHex, displayName: 'Bob Novák'),
};

/// Pumps the feed screen on top of a fake relay, with [friends] pre-added.
Future<AppState> _pumpFeed(
  WidgetTester tester, {
  List<String> friends = const <String>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 2000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{});

  final service = FakeRelayService(
    mine: <CheckinEvent>[_world().first],
    world: _world(),
    profiles: _profiles(),
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
      home: Scaffold(body: FeedScreen(app: app)),
    ),
  );
  await tester.pumpAndSettle();
  return app;
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

  testWidgets('lists my close ones with their kind 0 name and check-in', (
    tester,
  ) async {
    await _pumpFeed(tester, friends: <String>[friendNpub, quietFriendHex]);

    expect(find.text('Moji blízcí'), findsOneWidget);
    // Name from the kind 0 metadata: on the chip and on the check-in card.
    expect(find.text('Áňa'), findsNWidgets(2));
    // The check-in card of the friends section and the world stream.
    expect(find.text('Ranní klid'), findsNWidgets(2));
    // A friend without metadata falls back to the shortened key.
    expect(find.byKey(const Key('friend_chip_dd0000…')), findsOneWidget);
    expect(find.text('dd000000…00000'), findsOneWidget);
  });

  testWidgets('the world section hides my own check-ins', (tester) async {
    await _pumpFeed(tester, friends: <String>[friendNpub]);

    expect(find.text('Právě teď ve světě'), findsOneWidget);
    expect(find.text('Někdo úplně jiný'), findsOneWidget);
    // My check-in stays in my history, not in the world stream.
    expect(find.text('Moje vlastní poznámka'), findsNothing);
    // A friend's check-in shows in both sections.
    expect(find.text('Unavený den'), findsOneWidget);
  });

  testWidgets('shows the empty state before the first friend', (tester) async {
    await _pumpFeed(tester);

    expect(find.text('Zatím žádní přátelé.'), findsOneWidget);
    expect(find.byKey(const Key('feed_add_friend_cta')), findsOneWidget);
  });

  testWidgets('adding a friend by npub links profile and check-ins', (
    tester,
  ) async {
    final app = await _pumpFeed(tester);

    await tester.tap(find.byKey(const Key('feed_add_friend')));
    await tester.pumpAndSettle();

    // Invalid input keeps the confirm button disabled.
    await tester.enterText(
      find.byKey(const Key('friends_npub_field')),
      'garbage',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tohle není platný npub.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('friends_add_confirm')))
          .onPressed,
      isNull,
    );

    // A valid npub turns the hint green and adds the friend.
    await tester.enterText(
      find.byKey(const Key('friends_npub_field')),
      friendNpub,
    );
    await tester.pumpAndSettle();
    expect(find.text('Platný npub — můžeš přidat.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friends_add_confirm')));
    await tester.pumpAndSettle();

    expect(app.friends, <String>[friendHex]);
    expect(find.text('Áňa'), findsWidgets);
    expect(find.text('Ranní klid'), findsNWidgets(2));
  });

  testWidgets('removing a friend drops their check-ins from the feed', (
    tester,
  ) async {
    final app = await _pumpFeed(tester, friends: <String>[friendNpub, bobHex]);
    expect(find.text('Ranní klid'), findsNWidgets(2));

    // The chip's delete button asks for confirmation first.
    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();
    expect(find.text('Odebrat přítele?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('friends_remove_confirm')));
    await tester.pumpAndSettle();

    expect(app.friends, <String>[bobHex]);
    // The friends section drops her card; the anonymous world stream keeps the
    // check-in, so exactly one of the two cards is left.
    expect(find.text('Ranní klid'), findsOneWidget);
    expect(find.byKey(const Key('friend_chip_3bf0c6…')), findsNothing);
    expect(find.text('Unavený den'), findsWidgets);
  });

  testWidgets('sharing my npub opens the QR dialog', (tester) async {
    await _pumpFeed(tester, friends: <String>[friendNpub]);

    await tester.tap(find.byKey(const Key('feed_share_npub')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('friends_key_value')), findsOneWidget);
    expect(find.text('Můj npub'), findsWidgets);
    // The shared key is my own npub.
    expect(find.text(encodeNpub(meHex)), findsOneWidget);
  });
}
