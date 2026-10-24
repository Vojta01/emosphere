// Widget tests for the home shell (card 2/7): the bottom navigation and the
// floating "How do you feel?" button that opens the check-in sheet.

import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/screens/home_shell.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:emosphere/widgets/checkin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Platform channel of flutter_secure_storage.
///
/// Without a mock handler `FlutterSecureStorage.read` never completes, so
/// `AppState.init` would hang the test forever.
const MethodChannel _secureStorageChannel = MethodChannel(
  'plugins.it_nomads.com/flutter_secure_storage',
);

Future<AppState> _pumpShell(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  SharedPreferences.setMockInitialValues(<String, Object>{
    AppState.keyLanguage: 'cs',
  });
  final app = AppState();
  addTearDown(app.dispose);
  await app.init(autoSync: false);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: HomeShell(app: app),
    ),
  );
  await tester.pumpAndSettle();
  return app;
}

/// The four bottom-navigation entries, in order.
const Map<int, String> _sections = <int, String>{
  0: 'Mapa',
  1: 'Feed',
  2: 'Historie',
  3: 'Nastavení',
};

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  testWidgets('the bottom navigation offers map, feed, history, settings', (
    tester,
  ) async {
    await _pumpShell(tester);

    for (final entry in _sections.entries) {
      expect(
        find.descendant(
          of: find.byKey(Key('nav_${entry.key}')),
          matching: find.text(entry.value),
        ),
        findsOneWidget,
        reason: entry.value,
      );
    }
  });

  testWidgets('tapping a navigation item switches the visible section', (
    tester,
  ) async {
    await _pumpShell(tester);

    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);

    await tester.tap(find.byKey(const Key('nav_2')));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);

    await tester.tap(find.byKey(const Key('nav_3')));
    await tester.pumpAndSettle();
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 3);
  });

  testWidgets('the floating button opens the check-in sheet', (tester) async {
    await _pumpShell(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    expect(find.byType(CheckinSheet), findsOneWidget);
    expect(find.byKey(const Key('checkin_send')), findsOneWidget);
  });
}
