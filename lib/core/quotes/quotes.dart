// R11 — the quote library: 8 emotions × 20 curated reflective quotes in
// CZ + EN, bundled as `assets/quotes.json`. The after-send "afterglow"
// overlay picks one at random for every check-in.
//
// Attribution policy: traditional or uncertain attributions are marked in
// the `note` field ("attributed"); the UI shows a small hint for them.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../models/emotion.dart';

/// One curated quote: the English text, the Czech translation, the
/// attribution and an optional provenance note (e.g. 'attributed').
class Quote {
  const Quote({
    required this.en,
    required this.cz,
    required this.author,
    this.note = '',
  });

  /// Parses one JSON quote object.
  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
    en: json['en'] as String,
    cz: json['cz'] as String,
    author: json['author'] as String,
    note: json['note'] as String? ?? '',
  );

  /// English text.
  final String en;

  /// Czech translation.
  final String cz;

  /// Attribution shown under the quote (kept in its source language).
  final String author;

  /// Provenance note; 'attributed' marks traditional/uncertain attribution.
  final String note;

  /// The text of the given UI language.
  String text(String language) => language == 'en' ? en : cz;

  /// Whether the attribution is traditional or uncertain (shown as a hint).
  bool get isAttributed => note.toLowerCase().contains('attributed');
}

/// Loads and serves the bundled quote library.
class QuotesLibrary {
  QuotesLibrary._(this._byEmotion);

  final Map<Emotion, List<Quote>> _byEmotion;

  static QuotesLibrary? _instance;
  static final Random _random = Random();

  /// The library loaded at app start; null until [load] succeeds.
  static QuotesLibrary? get instance => _instance;

  /// Loads `assets/quotes.json` and publishes the result as [instance].
  /// Pass [bundle] in tests to load a different asset bundle.
  static Future<QuotesLibrary> load({AssetBundle? bundle}) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/quotes.json');
    final library = parse(raw);
    _instance = library;
    return library;
  }

  /// Parses the JSON document (one list per emotion slug). Visible for tests.
  static QuotesLibrary parse(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final byEmotion = <Emotion, List<Quote>>{};
    for (final emotion in Emotion.values) {
      final list = decoded[emotion.slug];
      byEmotion[emotion] = list is List
          ? [
              for (final item in list)
                Quote.fromJson((item as Map).cast<String, dynamic>()),
            ]
          : <Quote>[];
    }
    return QuotesLibrary._(byEmotion);
  }

  /// All quotes for [emotion]; empty when the emotion is missing.
  List<Quote> forEmotion(Emotion emotion) =>
      _byEmotion[emotion] ?? const <Quote>[];

  /// A random quote for [emotion]. Pass [random] for deterministic tests.
  /// Returns null when the library has no quotes for the emotion.
  Quote? randomFor(Emotion emotion, {Random? random}) {
    final quotes = forEmotion(emotion);
    if (quotes.isEmpty) return null;
    return quotes[(random ?? _random).nextInt(quotes.length)];
  }
}
