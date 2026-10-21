// Widget tests for the history screen (card 2/7): the check-in timeline plus
// the per-emotion and seven-day statistics.

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/screens/history_screen.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
}
