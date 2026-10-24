// Widget tests for the messages screens (R5): the conversation list with the
// unread badge and preview, the empty state, opening a chat, and sending a
// NIP-04 reply.

import 'dart:convert';

import 'package:emosphere/core/models/dm.dart';
import 'package:emosphere/core/models/profile.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/messages_screen.dart';
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

final DateTime now = DateTime.now().toUtc();

DmMessage _dm({
  required String id,
  required String from,
  required String to,
  required String text,
  required Duration ago,
}) {
  return DmMessage(
    id: id,
    senderPubkey: from,
    recipientPubkey: to,
    text: text,
    createdAt: now.subtract(ago),
  );
}

/// One thread with Bob: two incoming messages around one of mine.
List<DmMessage> _thread() => <DmMessage>[
  _dm(
    id: 'dm-1',
    from: bobHex,
    to: meHex,
    text: 'Ahoj, jak je?',
    ago: const Duration(minutes: 10),
  ),
  _dm(
    id: 'dm-2',
    from: meHex,
    to: bobHex,
    text: 'Dobře!',
    ago: const Duration(minutes: 5),
  ),
  _dm(
    id: 'dm-3',
    from: bobHex,
    to: meHex,
    text: 'Druhá zpráva',
    ago: const Duration(minutes: 2),
  ),
];

/// Pumps the messages screen on top of a fake relay.
///
/// [dms] are seeded into the local cache through SharedPreferences; the read
/// marker is set 15 minutes back so the two newest incoming messages count as
/// unread.
Future<(AppState, FakeRelayService)> _pumpMessages(
  WidgetTester tester, {
  List<DmMessage> dms = const <DmMessage>[],
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final initial = <String, Object>{};
  if (dms.isNotEmpty) {
    initial[AppState.keyDms] = jsonEncode(
      <Object>[for (final dm in dms) dm.toJson()],
    );
    initial[AppState.keyDmLastRead] = jsonEncode(<String, int>{
      bobHex: now
          .subtract(const Duration(minutes: 15))
          .millisecondsSinceEpoch,
    });
  }
  initial[AppState.keyLanguage] = 'cs';
  SharedPreferences.setMockInitialValues(initial);

  final service = FakeRelayService(
    dms: dms,
    profiles: <String, NostrProfile>{
      bobHex: NostrProfile(pubkey: bobHex, name: 'Bob Novák'),
    },
    pubkeyHex: meHex,
  );
  final app = AppState(service: service);
  addTearDown(app.dispose);
  await app.init(autoSync: false);

  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.dark(), home: MessagesScreen(app: app)),
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

  testWidgets('shows the empty state without conversations', (tester) async {
    await _pumpMessages(tester);

    expect(find.text('Zprávy'), findsOneWidget);
    expect(find.text('Zatím žádné zprávy.'), findsOneWidget);
    expect(find.text('Klepni ve feedu na někoho a napiš mu.'), findsOneWidget);
  });

  testWidgets('lists the conversation with the preview and unread badge', (
    tester,
  ) async {
    final (app, _) = await _pumpMessages(tester, dms: _thread());

    // Kind 0 name instead of the shortened key.
    expect(find.text('Bob Novák'), findsOneWidget);
    // Newest message preview, not prefixed with "Ty:" (it is incoming).
    expect(find.text('Druhá zpráva'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(app.unreadDmCount, 2);
  });

  testWidgets('opening a conversation shows the thread and clears the badge', (
    tester,
  ) async {
    final (app, _) = await _pumpMessages(tester, dms: _thread());

    await tester.tap(find.text('Bob Novák'));
    await tester.pumpAndSettle();

    expect(find.text('Ahoj, jak je?'), findsOneWidget);
    expect(find.text('Dobře!'), findsOneWidget);
    expect(find.text('Druhá zpráva'), findsOneWidget);
    expect(app.unreadDmCount, 0);

    // Back on the list the badge is gone.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('2'), findsNothing);
  });

  testWidgets('sending a reply publishes it and shows the bubble', (
    tester,
  ) async {
    final (app, service) = await _pumpMessages(tester, dms: _thread());

    await tester.tap(find.text('Bob Novák'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('dm_input')), 'Test odpověď');
    await tester.tap(find.byKey(const Key('dm_send')));
    await tester.pumpAndSettle();

    // Published through the service, addressed to Bob.
    expect(service.publishedDms, hasLength(1));
    expect(service.publishedDms.single.recipientPubkey, bobHex);
    expect(service.publishedDms.single.text, 'Test odpověď');
    // The bubble shows it and the input is cleared (one text hit, not two).
    expect(find.text('Test odpověď'), findsOneWidget);
    expect(app.conversationWith(bobHex), hasLength(4));
  });
}
