// EmoSphere check-in event model — Nostr kind 1074 (SPEC v0.3).
//
// Wire format:
//   kind: 1074 (regular event)
//   content: free note (max 140 chars, may be empty)
//   tags:
//     ["t", "emosphere"]      — global hashtag, always present
//     ["emotion", "<slug>"]   — EmoSphere-specific: the emotion slug
//     ["intensity", "<1-5>"]  — intensity
//     ["g", "<geohash>"]      — only when location sharing is enabled
//
// NOTE: single-letter NIP-01 tags like `e`/`i` are validated as fixed-size
// by modern relays (`e` must be a 64-char event id). Relays reject events
// that put arbitrary values there ("unexpected size for fixed-size tag"),
// so emotion and intensity use the full-word tag names above.

import 'package:dart_nostr/dart_nostr.dart';

import 'emotion.dart';

/// A single EmoSphere check-in.
class CheckinEvent {
  const CheckinEvent({
    required this.id,
    required this.pubkey,
    required this.emotion,
    required this.intensity,
    this.note = '',
    this.geohash,
    required this.createdAt,
  });

  /// Nostr kind for EmoSphere check-ins.
  static const int kindValue = 1074;

  /// Global hashtag used by the `t` tag.
  static const String hashtag = 'emosphere';

  /// Maximum note length in characters.
  static const int maxNoteLength = 140;

  /// Default intensity used when a received event has no valid `i` tag.
  static const int defaultIntensity = 3;

  /// Event id (64 hex chars) as assigned by Nostr.
  final String id;

  /// Author public key (64 hex chars).
  final String pubkey;

  /// Emotion of this check-in.
  final Emotion emotion;

  /// Intensity 1–5.
  final int intensity;

  /// Public note, at most [maxNoteLength] characters.
  final String note;

  /// Coarse location (geohash precision 3 or 5), or `null` when location is off.
  final String? geohash;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Builds the Nostr tag list for the given values.
  static List<List<String>> buildTags({
    required Emotion emotion,
    required int intensity,
    String? geohash,
  }) {
    return <List<String>>[
      <String>['t', hashtag],
      <String>['emotion', emotion.slug],
      <String>['intensity', normalizeIntensity(intensity).toString()],
      if (geohash != null && geohash.isNotEmpty) <String>['g', geohash],
    ];
  }

  /// Clamps [value] into the 1–5 intensity range.
  static int normalizeIntensity(int value) {
    if (value < 1) {
      return 1;
    }
    if (value > 5) {
      return 5;
    }
    return value;
  }

  /// Truncates [value] to [maxNoteLength] characters.
  static String normalizeNote(String value) {
    if (value.length <= maxNoteLength) {
      return value;
    }
    return value.substring(0, maxNoteLength);
  }

  /// Returns a signed Nostr event (kind 1074) for this check-in.
  ///
  /// [createdAt] overrides [CheckinEvent.createdAt] (used by tests).
  NostrEvent toNostrEvent(NostrKeyPairs keyPairs, {DateTime? createdAt}) {
    final timestamp = (createdAt ?? this.createdAt).toUtc();
    final seconds = DateTime.fromMillisecondsSinceEpoch(
      (timestamp.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    return NostrEvent.fromPartialData(
      kind: kindValue,
      content: normalizeNote(note),
      keyPairs: keyPairs,
      tags: buildTags(emotion: emotion, intensity: intensity, geohash: geohash),
      createdAt: seconds,
    );
  }

  /// Parses a check-in from a Nostr event.
  ///
  /// Returns `null` when the event is not an EmoSphere check-in (wrong kind,
  /// missing `t=emosphere` tag or unknown emotion slug). Missing or malformed
  /// intensity defaults to [defaultIntensity], out-of-range values are clamped.
  static CheckinEvent? fromNostrEvent(NostrEvent event) {
    if (event.kind != kindValue) {
      return null;
    }
    if (event.id == null) {
      return null;
    }
    final tags = event.tags ?? const <List<String>>[];
    var hasHashtag = false;
    String? slug;
    String? geohash;
    int? intensity;
    for (final tag in tags) {
      if (tag.length < 2) {
        continue;
      }
      switch (tag[0]) {
        case 't':
          if (tag[1] == hashtag) {
            hasHashtag = true;
          }
        case 'emotion':
        case 'e': // Legacy name from 0.1.1 — kept so old events still parse.
          slug ??= tag[1];
        case 'intensity':
        case 'i': // Legacy name from 0.1.1 — kept so old events still parse.
          intensity ??= int.tryParse(tag[1]);
        case 'g':
          geohash = tag[1];
      }
    }
    final emotion = Emotion.fromSlug(slug);
    if (!hasHashtag || emotion == null) {
      return null;
    }
    return CheckinEvent(
      id: event.id!,
      pubkey: event.pubkey,
      emotion: emotion,
      intensity: normalizeIntensity(intensity ?? defaultIntensity),
      note: event.content ?? '',
      geohash: (geohash != null && geohash.isNotEmpty) ? geohash : null,
      createdAt: (event.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toUtc(),
    );
  }

  /// Plain JSON map (used for the local check-in cache).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'pubkey': pubkey,
      'emotion': emotion.slug,
      'intensity': intensity,
      'note': note,
      'geohash': geohash,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Restores a check-in from [toJson]. Returns `null` for malformed maps.
  static CheckinEvent? fromJson(Map<String, dynamic> json) {
    final emotion = Emotion.fromSlug(json['emotion'] as String?);
    final id = json['id'] as String?;
    final pubkey = json['pubkey'] as String?;
    if (emotion == null || id == null || pubkey == null) {
      return null;
    }
    final seconds = (json['created_at'] as num?)?.toInt() ?? 0;
    return CheckinEvent(
      id: id,
      pubkey: pubkey,
      emotion: emotion,
      intensity: normalizeIntensity((json['intensity'] as num?)?.toInt() ?? 0),
      note: (json['note'] as String?) ?? '',
      geohash: json['geohash'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
        isUtc: true,
      ),
    );
  }

  @override
  String toString() {
    return 'CheckinEvent($emotion.slug x$intensity, ${note.length} chars, '
        'geohash: $geohash, $createdAt)';
  }
}
