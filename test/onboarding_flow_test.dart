// Widget tests for the first-run flow (card 5): the key backup step must be
// reachable. Regression guard: the root app used to swap to the home shell as
// soon as an identity existed, silently skipping the `nsec` backup step.

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/nostr/nostr_service.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform channel of flutter_secure_storage (see home_shell_test.dart).
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// In-memory stand-in for the secure storage behind the channel.
Map<String, String> _secureStore = <String, String>{};

void _installSecureStorageMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async {
    final args =
        (call.arguments as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    switch (call.method) {
      case 'write':
        _secureStore[args['key'] as String] = args['value'] as String;
        return null;
      case 'read':
        return _secureStore[args['key'] as String];
      case 'delete':
        _secureStore.remove(args['key'] as String);
        return null;
      case 'containsKey':
        return _secureStore.containsKey(args['key'] as String);
      case 'readAll':
        return Map<String, String>.of(_secureStore);
      case 'deleteAll':
        _secureStore.clear();
        return null;
    }
    return null;
  });
}

Future<AppState> _pumpApp(
  WidgetTester tester, {
  Map<String, Object> prefs = const <String, Object>{},
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(prefs);
  final app = AppState();
  addTearDown(app.dispose);
  await tester.pumpWidget(EmoSphereApp(app: app, autoSync: false));
  await tester.pumpAndSettle();
  return app;
}

/// Generates a key pair into the secure-storage mock (first run, no prefs).
Future<void> _seedStoredIdentity() async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final seed = AppState();
  await seed.init(autoSync: false);
  await seed.generateIdentity();
  seed.dispose();
  expect(_secureStore[NostrService.storageKeyPrivateKey], isNotNull);
}

void main() {
  final s = Strings('cs');

  setUp(() {
    _secureStore = <String, String>{};
    _installSecureStorageMock();
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('generating a key keeps onboarding open until backup confirmed', (
    tester,
  ) async {
    final app = await _pumpApp(tester);

    // Step 1 → 2.
    expect(find.text(s.tr('onb.step1.title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('onb_next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onb_generate')), findsOneWidget);

    // Generate the identity.
    await tester.tap(find.byKey(const Key('onb_generate')));
    await tester.pumpAndSettle();
    expect(app.hasIdentity, isTrue);

    // Regression: the app must stay in onboarding (no home shell yet).
    expect(find.text(s.tr('onb.step2.title')), findsOneWidget);
    expect(find.text(s.tr('home.fab')), findsNothing);

    // Continue to the backup step: nsec + QR + confirmation checkbox.
    await tester.tap(find.byKey(const Key('onb_next')));
    await tester.pumpAndSettle();
    expect(find.text(s.tr('onb.step3.title')), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text(s.tr('onb.finish')), findsOneWidget);

    // The finish button stays disabled until the backup is confirmed.
    await tester.tap(find.byKey(const Key('onb_next')));
    await tester.pumpAndSettle();
    expect(find.text(s.tr('home.fab')), findsNothing);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onb_next')));
    await tester.pumpAndSettle();

    // Finish → home shell and the flag is persisted.
    expect(find.text(s.tr('home.fab')), findsOneWidget);
    expect(app.onboardingComplete, isTrue);
  });

  testWidgets('an identity without a confirmed backup opens the backup step', (
    tester,
  ) async {
    await _seedStoredIdentity();

    final app = await _pumpApp(tester);

    expect(app.hasIdentity, isTrue);
    expect(find.text(s.tr('onb.step3.title')), findsOneWidget);
    expect(find.text(s.tr('home.fab')), findsNothing);
  });

  testWidgets('a finished onboarding opens the home shell directly', (
    tester,
  ) async {
    await _seedStoredIdentity();

    final app = await _pumpApp(
      tester,
      prefs: <String, Object>{AppState.keyOnboardingComplete: true},
    );

    expect(app.onboardingComplete, isTrue);
    expect(find.text(s.tr('home.fab')), findsOneWidget);
  });
}
