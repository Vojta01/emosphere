// Widget tests for the settings screen (card 2/7): relays, location precision,
// runtime CZ/EN switch, key backup (reveal + copy + QR) and the delete flow.

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/settings_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform channel of flutter_secure_storage — mocked so an identity can be
/// created in a headless test.
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

/// Host that mirrors `HomeShell`: it rebuilds the screen when [AppState]
/// changes, which is what makes the runtime language switch testable.
Future<AppState> _pumpSettings(
  WidgetTester tester, {
  bool withIdentity = false,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 2600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final app = AppState();
  addTearDown(app.dispose);
  await app.init(autoSync: false);
  if (withIdentity) {
    await app.generateIdentity();
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: ListenableBuilder(
          listenable: app,
          builder: (context, _) =>
              SettingsScreen(app: app, s: Strings(app.language)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      AppState.keyLanguage: 'cs',
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('shows every settings section', (tester) async {
    await _pumpSettings(tester);

    expect(find.text('Nastavení'), findsOneWidget);
    for (final title in <String>[
      'Profil',
      'Záloha klíče',
      'Jazyk',
      'Přesnost lokace',
      'Relaye',
      'Odkazy',
      'Smazat moje data',
      'O aplikaci',
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
    }
  });

  testWidgets('the relay editor starts from the current relay list', (
    tester,
  ) async {
    final app = await _pumpSettings(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, app.relays.join('\n'));
    expect(app.relays, hasLength(4));
  });

  testWidgets('the links card lists the project links', (tester) async {
    await _pumpSettings(tester);

    expect(find.byKey(const Key('settings_link_github')), findsOneWidget);
    expect(find.byKey(const Key('settings_link_apk')), findsOneWidget);
    expect(find.byKey(const Key('settings_link_web')), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('Android APK'), findsOneWidget);
    expect(find.text('Web (PWA)'), findsOneWidget);
  });

  testWidgets('switching the language re-renders the screen at runtime', (
    tester,
  ) async {
    await _pumpSettings(tester);
    expect(find.text('Nastavení'), findsOneWidget);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Key backup'), findsOneWidget);
    expect(find.text('Relays'), findsOneWidget);
    expect(find.text('Nastavení'), findsNothing);
  });

  testWidgets('key backup reveals the nsec and shows a QR code', (
    tester,
  ) async {
    final app = await _pumpSettings(tester, withIdentity: true);
    final nsec = app.nsec!;
    expect(nsec, startsWith('nsec1'));

    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.byKey(const Key('settings_reveal_key')));
    await tester.pumpAndSettle();

    // Masked by default, QR always available.
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('•' * 20), findsOneWidget);
    expect(find.text(nsec), findsNothing);

    await tester.tap(find.byKey(const Key('settings_key_toggle')));
    await tester.pumpAndSettle();
    expect(find.text(nsec), findsOneWidget);

    await tester.tap(find.text('Zavřít'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('deleting my data asks for confirmation first', (tester) async {
    await _pumpSettings(tester);

    await tester.tap(find.byKey(const Key('settings_delete_my_data')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Smazat moje data'), findsWidgets);
    expect(find.text('Zrušit'), findsOneWidget);

    await tester.tap(find.text('Zrušit'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('settings_delete_my_data')), findsOneWidget);
  });
}
