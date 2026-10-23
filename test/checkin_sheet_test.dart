// Widget tests for the check-in bottom sheet (card 2/7).
//
// The sheet is always opened through [showCheckinSheet] so the tests cover the
// real modal flow: emotion grid → intensity → note → location → send.

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/state/app_state.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:emosphere/widgets/checkin_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the sheet handed to the publish callback.
class _PublishLog {
  int calls = 0;
  Emotion? emotion;
  int? intensity;
  String? note;
  LocationPrecision? precision;
}

/// Pumps a host screen and opens the sheet from it.
Future<void> _openSheet(
  WidgetTester tester, {
  required CheckinPublish publish,
  Strings s = Strings.cs,
  LocationPrecision initialPrecision = LocationPrecision.off,
  void Function(CheckinResult? result)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async {
                final result = await showCheckinSheet(
                  context,
                  s: s,
                  publish: publish,
                  initialPrecision: initialPrecision,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// A tall surface so the whole sheet is on screen (default is 800×600).
Future<void> _useTallSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(500, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

FilledButton _sendButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('checkin_send')));

void main() {
  testWidgets('renders eight emotions, intensity, note and location', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await _openSheet(tester, publish: (_, _, _, _) async {});

    expect(find.text(Strings.cs.tr('checkin.title')), findsOneWidget);
    for (final emotion in Emotion.values) {
      expect(
        find.byKey(Key('emotion_${emotion.slug}')),
        findsOneWidget,
        reason: 'missing tile for ${emotion.slug}',
      );
    }
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byKey(const Key('checkin_note')), findsOneWidget);
    expect(find.byType(SegmentedButton<LocationPrecision>), findsOneWidget);
  });

  testWidgets('picking an emotion enables Send', (tester) async {
    await _useTallSurface(tester);
    await _openSheet(tester, publish: (_, _, _, _) async {});

    expect(_sendButton(tester).onPressed, isNull, reason: 'starts disabled');

    await tester.tap(find.byKey(const Key('emotion_joy')));
    await tester.pumpAndSettle();

    expect(_sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('Send publishes emotion, intensity, note and location', (
    tester,
  ) async {
    await _useTallSurface(tester);
    final log = _PublishLog();
    CheckinResult? result;
    await _openSheet(
      tester,
      publish: (emotion, intensity, note, precision) async {
        log.calls += 1;
        log.emotion = emotion;
        log.intensity = intensity;
        log.note = note;
        log.precision = precision;
      },
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const Key('emotion_calm')));
    await tester.pump();
    await tester.drag(find.byType(Slider), const Offset(600, 0));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('checkin_note')),
      'Pohoda u kávy',
    );
    await tester.pump();
    await tester.tap(find.text(Strings.cs.tr('checkin.locCity')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('checkin_send')));
    await tester.pump();

    expect(log.calls, 1);
    expect(log.emotion, Emotion.calm);
    expect(log.intensity, 5);
    expect(log.note, 'Pohoda u kávy');
    expect(log.precision, LocationPrecision.city);

    // Confirmation overlay (haptic + animated check mark), then auto close.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();

    expect(find.byType(CheckinSheet), findsNothing);
    expect(result?.emotion, Emotion.calm);
    expect(result?.intensity, 5);
  });

  testWidgets('a failed publish keeps the sheet open and shows the error', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await _openSheet(
      tester,
      publish: (_, _, _, _) async => throw Exception('relay down'),
    );

    await tester.tap(find.byKey(const Key('emotion_anger')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('checkin_send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(Strings.cs.tr('checkin.failed')), findsOneWidget);
    expect(find.byType(CheckinSheet), findsOneWidget);
    expect(_sendButton(tester).onPressed, isNotNull, reason: 'can retry');
  });

  testWidgets('the note is capped at 140 characters', (tester) async {
    await _useTallSurface(tester);
    await _openSheet(tester, publish: (_, _, _, _) async {});

    await tester.enterText(find.byKey(const Key('checkin_note')), 'x' * 200);
    await tester.pump();

    final field = tester.widget<TextField>(
      find.byKey(const Key('checkin_note')),
    );
    expect(field.controller!.text.length, 140);
  });

  testWidgets('the location picker starts from the app setting', (
    tester,
  ) async {
    await _useTallSurface(tester);
    await _openSheet(
      tester,
      publish: (_, _, _, _) async {},
      initialPrecision: LocationPrecision.city,
    );

    final picker = tester.widget<SegmentedButton<LocationPrecision>>(
      find.byType(SegmentedButton<LocationPrecision>),
    );
    expect(picker.selected, <LocationPrecision>{LocationPrecision.city});
  });

  testWidgets('the sheet follows the CZ/EN language switch', (tester) async {
    await _useTallSurface(tester);
    await _openSheet(tester, s: Strings.en, publish: (_, _, _, _) async {});

    expect(find.text('How do you feel?'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('City'), findsOneWidget);
    expect(find.text('Odeslat'), findsNothing);
  });
}
