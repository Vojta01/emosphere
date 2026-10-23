// Unit tests for the bundled quote library (R11).
//
// The library ships as `assets/quotes.json` (8 emotions × 20 quotes) and is
// loaded once at app start; these tests keep the asset honest.

import 'dart:math';

import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/quotes/quotes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled asset', () {
    test('every emotion has exactly 20 quotes', () async {
      final lib = await QuotesLibrary.load();
      for (final emotion in Emotion.values) {
        expect(lib.forEmotion(emotion).length, 20, reason: emotion.slug);
      }
    });

    test('every quote has en, cz and author', () async {
      final lib = await QuotesLibrary.load();
      for (final emotion in Emotion.values) {
        for (final quote in lib.forEmotion(emotion)) {
          expect(quote.en.trim(), isNotEmpty, reason: emotion.slug);
          expect(quote.cz.trim(), isNotEmpty, reason: emotion.slug);
          expect(quote.author.trim(), isNotEmpty, reason: emotion.slug);
        }
      }
    });

    test('no quote text repeats across emotions', () async {
      final lib = await QuotesLibrary.load();
      final seen = <String>{};
      for (final emotion in Emotion.values) {
        for (final quote in lib.forEmotion(emotion)) {
          final key = quote.en.trim().toLowerCase();
          expect(
            seen.add(key),
            isTrue,
            reason: 'duplicate quote in ${emotion.slug}: ${quote.en}',
          );
        }
      }
    });

    test('randomFor returns a quote of the requested emotion', () async {
      final lib = await QuotesLibrary.load();
      final rng = Random(7);
      for (final emotion in Emotion.values) {
        final quote = lib.randomFor(emotion, random: rng);
        expect(quote, isNotNull, reason: emotion.slug);
        expect(lib.forEmotion(emotion).contains(quote), isTrue);
        expect(quote!.text('en'), quote.en);
        expect(quote.text('cs'), quote.cz);
      }
    });
  });

  group('parse', () {
    test('tolerates missing emotions', () {
      final lib = QuotesLibrary.parse(
        '{"joy": [{"en":"A","cz":"B","author":"C"}]}',
      );
      expect(lib.forEmotion(Emotion.joy).single.author, 'C');
      expect(lib.forEmotion(Emotion.fear), isEmpty);
      expect(lib.randomFor(Emotion.fear), isNull);
    });

    test('notes mark traditional attributions', () {
      const quote = Quote(en: 'x', cz: 'y', author: 'z', note: 'attributed');
      expect(quote.isAttributed, isTrue);
      const plain = Quote(en: 'x', cz: 'y', author: 'z');
      expect(plain.isAttributed, isFalse);
    });
  });
}
