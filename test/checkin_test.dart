// Tests for the EmoSphere check-in model — Nostr kind 1074 round-trip,
// tag construction and parsing rules (SPEC v0.3).

import 'package:dart_nostr/dart_nostr.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

/// Deterministic key pair: private key `…0001`, public key = G.
const String testPrivateKey =
    '0000000000000000000000000000000000000000000000000000000000000001';
const String testPubkey =
    '79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const String otherPubkey =
    'aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11';

/// Repeats [unit] [times] times (Dart has no string multiplication).
String repeat(String unit, int times) =>
    List<String>.filled(times, unit).join();

/// Builds a relay-style EVENT message and parses it, so negative tests can
/// craft arbitrary (even invalid) events.
NostrEvent relayEvent({
  int kind = CheckinEvent.kindValue,
  String content = '',
  List<List<String>>? tags,
  DateTime? createdAt,
  String id =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
  String pubkey = otherPubkey,
}) {
  return NostrEvent.fromDecodedMessage(<dynamic>[
    'EVENT',
    'test-sub',
    <String, dynamic>{
      'id': id,
      'kind': kind,
      'content': content,
      'sig': repeat('0', 128),
      'pubkey': pubkey,
      'created_at':
          (createdAt ?? DateTime.utc(2026, 10, 21)).millisecondsSinceEpoch ~/
          1000,
      'tags':
          tags ??
          <List<String>>[
            <String>['t', CheckinEvent.hashtag],
            <String>['e', 'joy'],
            <String>['i', '3'],
          ],
    },
  ]);
}

void main() {
  late NostrKeyPairs keys;
  final createdAt = DateTime.utc(2026, 10, 21, 20, 30);

  setUpAll(() {
    keys = NostrKeyPairs(private: testPrivateKey);
  });

  group('Emotion', () {
    test('has the eight SPEC colours and unique slugs', () {
      expect(Emotion.values, hasLength(8));
      expect(Emotion.joy.color, const Color(0xFFFFD93D));
      expect(Emotion.calm.color, const Color(0xFF4ADE80));
      expect(Emotion.love.color, const Color(0xFFF472B6));
      expect(Emotion.surprise.color, const Color(0xFFFB923C));
      expect(Emotion.sadness.color, const Color(0xFF60A5FA));
      expect(Emotion.anger.color, const Color(0xFFEF4444));
      expect(Emotion.fear.color, const Color(0xFFA78BFA));
      expect(Emotion.tiredness.color, const Color(0xFF94A3B8));
      expect(Emotion.values.map((e) => e.slug).toSet(), hasLength(8));
    });

    test('resolves slugs and localizes labels', () {
      expect(Emotion.fromSlug('joy'), Emotion.joy);
      expect(Emotion.fromSlug('nope'), isNull);
      expect(Emotion.fromSlug(null), isNull);
      expect(Emotion.joy.label('cs'), 'Radost');
      expect(Emotion.joy.label('en'), 'Joy');
      expect(Emotion.sadness.label('en'), 'Sadness');
    });
  });

  group('buildTags', () {
    test('writes t, e, i and g tags in the SPEC order', () {
      final tags = CheckinEvent.buildTags(
        emotion: Emotion.joy,
        intensity: 4,
        geohash: 'u2f',
      );
      expect(tags, <List<String>>[
        <String>['t', 'emosphere'],
        <String>['e', 'joy'],
        <String>['i', '4'],
        <String>['g', 'u2f'],
      ]);
    });

    test('omits the g tag when the location is off', () {
      final tags = CheckinEvent.buildTags(emotion: Emotion.calm, intensity: 2);
      expect(tags, hasLength(3));
      expect(tags.any((tag) => tag[0] == 'g'), isFalse);
      expect(
        CheckinEvent.buildTags(
          emotion: Emotion.calm,
          intensity: 2,
          geohash: '',
        ).any((tag) => tag[0] == 'g'),
        isFalse,
      );
    });

    test('clamps the intensity into 1..5', () {
      expect(
        CheckinEvent.buildTags(emotion: Emotion.anger, intensity: 9)[2],
        <String>['i', '5'],
      );
      expect(
        CheckinEvent.buildTags(emotion: Emotion.anger, intensity: 0)[2],
        <String>['i', '1'],
      );
    });
  });

  group('toNostrEvent', () {
    test('creates a signed kind 1074 event with the right content', () {
      final checkin = CheckinEvent(
        id: '',
        pubkey: testPubkey,
        emotion: Emotion.love,
        intensity: 5,
        note: 'hello world',
        geohash: 'u2fkb',
        createdAt: createdAt,
      );
      final event = checkin.toNostrEvent(keys);

      expect(event.kind, CheckinEvent.kindValue);
      expect(event.kind, 1074);
      expect(event.content, 'hello world');
      expect(event.pubkey, testPubkey);
      expect(event.tags, <List<String>>[
        <String>['t', 'emosphere'],
        <String>['e', 'love'],
        <String>['i', '5'],
        <String>['g', 'u2fkb'],
      ]);
      expect(event.createdAt, createdAt);
      expect(event.id, isNotNull);
      expect(
        event.id,
        NostrEvent.getEventId(
          kind: 1074,
          content: 'hello world',
          createdAt: createdAt,
          tags: event.tags!,
          pubkey: testPubkey,
        ),
      );
      // The signature is valid for the generated id.
      expect(NostrKeyPairs.verify(testPubkey, event.id!, event.sig!), isTrue);
    });

    test('keeps an empty note empty and truncates to 140 characters', () {
      final empty = CheckinEvent(
        id: '',
        pubkey: testPubkey,
        emotion: Emotion.calm,
        intensity: 3,
        createdAt: createdAt,
      ).toNostrEvent(keys);
      expect(empty.content, '');

      final long = CheckinEvent(
        id: '',
        pubkey: testPubkey,
        emotion: Emotion.calm,
        intensity: 3,
        note: repeat('x', 200),
        createdAt: createdAt,
      ).toNostrEvent(keys);
      expect(long.content, hasLength(CheckinEvent.maxNoteLength));
      expect(long.content, repeat('x', 140));
    });

    test('uses whole-second timestamps', () {
      final withMillis = DateTime.utc(2026, 10, 21, 20, 30, 45, 123);
      final event = CheckinEvent(
        id: '',
        pubkey: testPubkey,
        emotion: Emotion.joy,
        intensity: 3,
        createdAt: withMillis,
      ).toNostrEvent(keys);
      expect(event.createdAt!.millisecond, 0);
      expect(event.createdAt, DateTime.utc(2026, 10, 21, 20, 30, 45));
    });
  });

  group('fromNostrEvent', () {
    test('round-trips every field of a signed event', () {
      final original = CheckinEvent(
        id: '',
        pubkey: testPubkey,
        emotion: Emotion.fear,
        intensity: 4,
        note: 'round trip',
        geohash: 'u2f',
        createdAt: createdAt,
      );
      final event = original.toNostrEvent(keys);
      final parsed = CheckinEvent.fromNostrEvent(event);

      expect(parsed, isNotNull);
      expect(parsed!.id, event.id);
      expect(parsed.pubkey, testPubkey);
      expect(parsed.emotion, Emotion.fear);
      expect(parsed.intensity, 4);
      expect(parsed.note, 'round trip');
      expect(parsed.geohash, 'u2f');
      expect(parsed.createdAt, createdAt);
    });

    test(
      'ignores events of other kinds, without the t tag or unknown slug',
      () {
        expect(CheckinEvent.fromNostrEvent(relayEvent(kind: 1)), isNull);
        expect(
          CheckinEvent.fromNostrEvent(
            relayEvent(
              tags: <List<String>>[
                <String>['e', 'joy'],
                <String>['i', '3'],
              ],
            ),
          ),
          isNull,
        );
        expect(
          CheckinEvent.fromNostrEvent(
            relayEvent(
              tags: <List<String>>[
                <String>['t', 'emosphere'],
                <String>['e', 'confusion'],
                <String>['i', '3'],
              ],
            ),
          ),
          isNull,
        );
      },
    );

    test('defaults a missing or malformed intensity to 3', () {
      final withoutIntensity = CheckinEvent.fromNostrEvent(
        relayEvent(
          tags: <List<String>>[
            <String>['t', 'emosphere'],
            <String>['e', 'joy'],
          ],
        ),
      );
      expect(withoutIntensity!.intensity, CheckinEvent.defaultIntensity);

      final malformed = CheckinEvent.fromNostrEvent(
        relayEvent(
          tags: <List<String>>[
            <String>['t', 'emosphere'],
            <String>['e', 'joy'],
            <String>['i', 'abc'],
          ],
        ),
      );
      expect(malformed!.intensity, 3);
    });

    test('clamps out-of-range intensity from the relay', () {
      final high = CheckinEvent.fromNostrEvent(
        relayEvent(
          tags: <List<String>>[
            <String>['t', 'emosphere'],
            <String>['e', 'joy'],
            <String>['i', '42'],
          ],
        ),
      );
      expect(high!.intensity, 5);

      final low = CheckinEvent.fromNostrEvent(
        relayEvent(
          tags: <List<String>>[
            <String>['t', 'emosphere'],
            <String>['e', 'joy'],
            <String>['i', '-3'],
          ],
        ),
      );
      expect(low!.intensity, 1);
    });

    test('drops an empty geohash tag', () {
      final parsed = CheckinEvent.fromNostrEvent(
        relayEvent(
          tags: <List<String>>[
            <String>['t', 'emosphere'],
            <String>['e', 'joy'],
            <String>['i', '3'],
            <String>['g', ''],
          ],
        ),
      );
      expect(parsed!.geohash, isNull);
    });

    test('reads the note from the event content', () {
      final parsed = CheckinEvent.fromNostrEvent(
        relayEvent(content: 'from the relay'),
      );
      expect(parsed!.note, 'from the relay');
    });
  });

  group('local JSON cache', () {
    test('round-trips through toJson/fromJson', () {
      final original = CheckinEvent(
        id: repeat('a', 64),
        pubkey: otherPubkey,
        emotion: Emotion.tiredness,
        intensity: 2,
        note: 'cached',
        geohash: 'u2e',
        createdAt: createdAt,
      );
      final restored = CheckinEvent.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.pubkey, original.pubkey);
      expect(restored.emotion, original.emotion);
      expect(restored.intensity, original.intensity);
      expect(restored.note, original.note);
      expect(restored.geohash, original.geohash);
      expect(restored.createdAt, original.createdAt);
    });

    test('returns null for malformed maps', () {
      expect(CheckinEvent.fromJson(<String, dynamic>{}), isNull);
      expect(
        CheckinEvent.fromJson(<String, dynamic>{
          'id': repeat('a', 64),
          'pubkey': otherPubkey,
          'emotion': 'unknown',
        }),
        isNull,
      );
    });
  });

  group('normalization helpers', () {
    test('normalizeIntensity clamps to 1..5', () {
      expect(CheckinEvent.normalizeIntensity(0), 1);
      expect(CheckinEvent.normalizeIntensity(1), 1);
      expect(CheckinEvent.normalizeIntensity(3), 3);
      expect(CheckinEvent.normalizeIntensity(5), 5);
      expect(CheckinEvent.normalizeIntensity(6), 5);
    });

    test('normalizeNote truncates to 140 characters', () {
      expect(CheckinEvent.normalizeNote('short'), 'short');
      expect(CheckinEvent.normalizeNote(repeat('y', 141)), hasLength(140));
    });
  });
}
