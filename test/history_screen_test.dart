// Widget tests for the history screen (card 2/7): the check-in timeline plus
// the per-emotion and seven-day statistics, and the check-in detail sheet
// with the reflective quote (R11).

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/quotes/quotes.dart';
import 'package:emosphere/screens/history_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

CheckinEvent _checkin({
  required Emotion emotion,
  required int intensity,
  required DateTime createdAt,
  String note = '',
  String id = 'a',
}) => CheckinEvent(
  id: id.padRight(64, '0'),
  pubkey: 'b' * 64,
  emotion: emotion,
  intensity: intensity,
  note: note,
  createdAt: createdAt,
);

Future<void> _pumpHistory(
  WidgetTester tester,
  List<CheckinEvent> checkins, {
  Strings s = Strings.cs,
}) async {
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: HistoryScreen(s: s, checkins: checkins),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the empty state invites the first check-in', (tester) async {
    await _pumpHistory(tester, const <CheckinEvent>[]);

    expect(find.text(Strings.cs.tr('hist.empty')), findsOneWidget);
    expect(find.text(Strings.cs.tr('hist.last7')), findsNothing);
  });

  testWidgets('lists my check-ins with per-emotion and per-day statistics', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await _pumpHistory(tester, <CheckinEvent>[
      _checkin(
        emotion: Emotion.joy,
        intensity: 5,
        createdAt: now,
        note: 'Slunce',
        id: 'c1',
      ),
      _checkin(
        emotion: Emotion.joy,
        intensity: 2,
        createdAt: now.subtract(const Duration(days: 3)),
        id: 'c2',
      ),
      _checkin(
        emotion: Emotion.sadness,
        intensity: 3,
        createdAt: now.subtract(const Duration(days: 3)),
        id: 'c3',
      ),
    ]);

    expect(find.text(Strings.cs.tr('hist.title')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('hist_total'))).data, '3');

    // Per-emotion rows (statistics) and the timeline cards.
    expect(find.text('Radost'), findsWidgets);
    expect(find.text('Smutek'), findsWidgets);
    expect(find.text('Slunce'), findsOneWidget);

    // Seven-day mini chart: one column per day, counts per bucket.
    expect(find.text(Strings.cs.tr('hist.last7')), findsOneWidget);
    final today = DateTime.now().weekday;
    expect(
      tester.widget<Text>(find.byKey(Key('day_count_$today'))).data,
      '1',
      reason: 'today',
    );
    final threeDaysAgo = now
        .subtract(const Duration(days: 3))
        .toLocal()
        .weekday;
    expect(
      tester.widget<Text>(find.byKey(Key('day_count_$threeDaysAgo'))).data,
      '2',
      reason: 'three days ago',
    );
    expect(find.text('Po'), findsOneWidget);
    expect(find.text('Ne'), findsOneWidget);
  });

  testWidgets('the English strings drive the statistics labels', (
    tester,
  ) async {
    await _pumpHistory(tester, <CheckinEvent>[
      _checkin(
        emotion: Emotion.calm,
        intensity: 4,
        createdAt: DateTime.now().toUtc(),
      ),
    ], s: Strings.en);

    expect(find.text('Last 7 days'), findsOneWidget);
    expect(find.text('My check-ins'), findsOneWidget);
    expect(find.text('Calm'), findsWidgets);
    expect(find.text('Total check-ins'), findsOneWidget);

    const english = <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    expect(find.text(english[DateTime.now().weekday - 1]), findsOneWidget);
  });

  testWidgets('tapping a check-in opens the detail with a reflective quote', (
    tester,
  ) async {
    // A tiny in-memory library: two joy quotes (the pick is random).
    await QuotesLibrary.load(bundle: _FakeQuotesBundle());

    await _pumpHistory(tester, <CheckinEvent>[
      _checkin(
        emotion: Emotion.joy,
        intensity: 4,
        createdAt: DateTime.now().toUtc(),
        note: 'Slunce',
        id: 'd1',
      ),
    ]);

    await tester.tap(find.text('Slunce'));
    await tester.pumpAndSettle();

    // The sheet: the emotion header, the reflection label and one of the
    // two quotes ("Author" appears in both attributions).
    expect(find.byKey(const Key('detail_emotion')), findsOneWidget);
    expect(find.text(Strings.cs.tr('hist.reflection')), findsOneWidget);
    expect(find.byKey(const Key('history_quote')), findsOneWidget);
    expect(find.textContaining('Author'), findsOneWidget);
  });
}

/// `assets/quotes.json` stand-in with two joy quotes and empty other lists.
const String _quotesJson = '{'
    '"joy":['
    '{"en":"Twinkle","cz":"Třpyt","author":"A. Author","note":""},'
    '{"en":"Sunny","cz":"Slunečno","author":"B. Author","note":"attributed"}'
    '],'
    '"calm":[],"love":[],"surprise":[],"sadness":[],"anger":[],"fear":[],'
    '"tiredness":[]'
    '}';

/// In-memory asset bundle: resolves the quotes asset synchronously so the
/// widget test does not need real file I/O.
class _FakeQuotesBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) =>
      throw FlutterError('Unexpected asset load: $key');

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      SynchronousFuture(_quotesJson);
}
