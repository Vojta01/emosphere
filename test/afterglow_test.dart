// Widget tests for the after-send afterglow (R10 + R11): the particle run,
// the skip-ahead tap and the quote card.

import 'package:emosphere/core/i18n/strings.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/quotes/quotes.dart';
import 'package:emosphere/theme/app_theme.dart';
import 'package:emosphere/widgets/afterglow_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Quote _quote = Quote(
  en: 'Smile, breathe and go slowly.',
  cz: 'Usmívej se, dýchej a jdi pomalu.',
  author: 'Thich Nhat Hanh',
);

const Quote _attributed = Quote(
  en: 'Muddy water is best cleared by leaving it alone.',
  cz: 'Kalnou vodu nejlépe vyčeříš, když ji necháš být.',
  author: 'Alan Watts',
  note: 'attributed',
);

/// Pumps a host screen and opens the afterglow from it.
Future<void> _open(
  WidgetTester tester, {
  Strings s = Strings.cs,
  Quote quote = _quote,
  bool haptics = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAfterglow(
                context,
                s: s,
                emotion: Emotion.calm,
                intensity: 4,
                quote: quote,
                haptics: haptics,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400)); // route fade-in
}

void main() {
  testWidgets('the quote appears after the particle run', (tester) async {
    await _open(tester);

    expect(_quoteOpacity(tester), 0);

    await tester.pump(const Duration(milliseconds: 4200));
    await tester.pumpAndSettle();

    expect(_quoteOpacity(tester), 1);
    expect(find.textContaining('Usmívej se'), findsOneWidget);
    expect(find.textContaining('Thich Nhat Hanh'), findsOneWidget);
  });

  testWidgets('the first tap skips ahead, the next tap closes', (
    tester,
  ) async {
    await _open(tester);

    // While the particles run, a tap skips ahead to the quote…
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(_quoteOpacity(tester), 1);
    expect(find.textContaining('Usmívej se'), findsOneWidget);

    // …and once the quote is visible, a tap closes the overlay.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(AfterglowOverlay), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('follows the CZ/EN language switch', (tester) async {
    await _open(tester, s: Strings.en);

    await tester.pump(const Duration(milliseconds: 4200));

    expect(find.textContaining('Smile, breathe'), findsOneWidget);
    expect(find.text('Tap anywhere to close'), findsOneWidget);
    expect(find.textContaining('Usmívej se'), findsNothing);
  });

  testWidgets('attributed quotes carry the attribution hint', (tester) async {
    await _open(tester, quote: _attributed);

    await tester.pump(const Duration(milliseconds: 4200));

    expect(find.textContaining('Alan Watts'), findsOneWidget);
    expect(find.text(Strings.cs.tr('quote.attributed')), findsOneWidget);
  });

  testWidgets('plays with haptics enabled without crashing', (tester) async {
    await _open(tester, haptics: true);

    await tester.pump(const Duration(milliseconds: 4200));

    expect(find.textContaining('Usmívej se'), findsOneWidget);
  });
}

/// Opacity of the quote card (0 while the particles run, 1 once it arrived).
double _quoteOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(const Key('afterglow_quote')),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;
