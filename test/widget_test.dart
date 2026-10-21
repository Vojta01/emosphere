// Smoke tests for the theme tokens the screens build on.

import 'package:emosphere/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('SPEC colours: accent and background gradient', () {
    expect(AppTheme.accent, const Color(0xFF6366F1));
    expect(AppTheme.backgroundGradient.colors.first, const Color(0xFF0B1020));
    expect(AppTheme.backgroundGradient.colors.last, const Color(0xFF0E1430));
  });

  test('emotion palette exposes all eight colours', () {
    expect(AppTheme.emotionColors, hasLength(8));
    expect(AppTheme.emotionColors.first, const Color(0xFFFFD93D));
  });

  testWidgets('GlassCard renders inside the dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: Center(child: GlassCard(child: Text('EmoSphere'))),
        ),
      ),
    );
    expect(find.text('EmoSphere'), findsOneWidget);
  });
}
