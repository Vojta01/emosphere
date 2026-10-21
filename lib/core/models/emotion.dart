// EmoSphere — the eight emotions (SPEC v0.3).
//
// The [Emotion.slug] values are stable identifiers written into the Nostr
// `e` tag of every check-in event. Never rename an existing slug.

import 'package:flutter/material.dart';

/// The eight EmoSphere emotions with their palette, localized labels and emoji.
enum Emotion {
  /// Joy / radost.
  joy('joy', Color(0xFFFFD93D), 'Radost', 'Joy', '😄'),

  /// Calm / klid.
  calm('calm', Color(0xFF4ADE80), 'Klid', 'Calm', '😌'),

  /// Love / láska.
  love('love', Color(0xFFF472B6), 'Láska', 'Love', '❤️'),

  /// Surprise / překvapení.
  surprise('surprise', Color(0xFFFB923C), 'Překvapení', 'Surprise', '😮'),

  /// Sadness / smutek.
  sadness('sadness', Color(0xFF60A5FA), 'Smutek', 'Sadness', '😢'),

  /// Anger / vztek.
  anger('anger', Color(0xFFEF4444), 'Vztek', 'Anger', '😠'),

  /// Fear / strach.
  fear('fear', Color(0xFFA78BFA), 'Strach', 'Fear', '😨'),

  /// Tiredness / únava.
  tiredness('tiredness', Color(0xFF94A3B8), 'Únava', 'Tiredness', '😴');

  const Emotion(this.slug, this.color, this.labelCz, this.labelEn, this.emoji);

  /// Stable identifier used in the Nostr `e` tag (lowercase English word).
  final String slug;

  /// Primary colour from the SPEC palette.
  final Color color;

  /// Czech label.
  final String labelCz;

  /// English label.
  final String labelEn;

  /// Emoji shown in compact UI.
  final String emoji;

  /// Localized label. [lang] is `'cs'` (default) or `'en'`.
  String label(String lang) => lang == 'en' ? labelEn : labelCz;

  /// Resolves an emotion from its Nostr [slug]. Returns `null` if unknown.
  static Emotion? fromSlug(String? slug) {
    if (slug == null) {
      return null;
    }
    for (final emotion in Emotion.values) {
      if (emotion.slug == slug) {
        return emotion;
      }
    }
    return null;
  }
}
