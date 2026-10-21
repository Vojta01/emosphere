// Guards for the CZ/EN dictionary: every `tr('…')` key used in lib/ must
// exist in both languages, and language selection must fall back safely.

import 'dart:io';

import 'package:emosphere/core/i18n/strings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every tr() key used in lib/ is translated in CZ and EN', () {
    final used = <String>{};
    final pattern = RegExp(r"""\.tr\(\s*'((?:[^'\\]|\\.)+)'\s*\)""");
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      final source = entity.readAsStringSync();
      used.addAll(pattern.allMatches(source).map((match) => match.group(1)!));
    }
    expect(used, isNotEmpty, reason: 'expected tr() usages in lib/');
    for (final key in used) {
      if (key.contains(r'$') || key.contains('{')) {
        continue; // Interpolated key — resolved at runtime.
      }
      expect(Strings.cs.hasKey(key), isTrue, reason: 'missing key: $key');
      expect(Strings.en.hasKey(key), isTrue, reason: 'missing key: $key');
      expect(Strings.cs.t(key), isNot(key), reason: 'no CZ text for: $key');
      expect(Strings.en.t(key), isNot(key), reason: 'no EN text for: $key');
    }
  });

  test('language selection and fallbacks', () {
    expect(Strings('en').language, 'en');
    expect(Strings('cs').code, 'cs');
    expect(Strings('de').code, 'cs', reason: 'unknown codes fall back to CZ');
    expect(Strings.of('en'), Strings.en);
    expect(Strings.of(null), Strings.cs);
    expect(Strings.supportedCodes, <String>['cs', 'en']);
    expect(Strings.cs.isEnglish, isFalse);
    expect(Strings.en.isEnglish, isTrue);
    expect(Strings.en.t('appName'), 'EmoSphere');
  });

  test('placeholders survive in both languages', () {
    for (final key in <String>['hist.minAgo', 'hist.hAgo', 'hist.dAgo']) {
      expect(Strings.cs.t(key), contains('{n}'), reason: key);
      expect(Strings.en.t(key), contains('{n}'), reason: key);
    }
  });

  test('unknown keys return the key itself (no crash)', () {
    expect(Strings.cs.t('does.not.exist'), 'does.not.exist');
    expect(Strings.cs.hasKey('does.not.exist'), isFalse);
  });

  test('checkinsCount uses Czech plural rules', () {
    expect(Strings.cs.checkinsCount(1), '1 check-in');
    expect(Strings.cs.checkinsCount(3), '3 check-iny');
    expect(Strings.cs.checkinsCount(12), '12 check-inů');
    expect(Strings.en.checkinsCount(1), '1 check-in');
    expect(Strings.en.checkinsCount(3), '3 check-ins');
  });

  test('timeAgo speaks CZ and EN', () {
    final now = DateTime.utc(2026, 10, 21, 12);
    expect(
      Strings.cs.timeAgo(now.subtract(const Duration(seconds: 30)), now: now),
      'právě teď',
    );
    expect(
      Strings.en.timeAgo(now.subtract(const Duration(seconds: 30)), now: now),
      'just now',
    );
    expect(
      Strings.en.timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      '5 min ago',
    );
    expect(
      Strings.cs.timeAgo(now.subtract(const Duration(minutes: 5)), now: now),
      'před 5 min',
    );
  });
}
