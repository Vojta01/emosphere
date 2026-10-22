// Regression guard for the Nostr wire format.
//
// History: the first release put the emotion slug into an `e` tag and the
// intensity into an `i` tag. Modern relays validate single-letter NIP-01
// tags as fixed-size (`e` must hold a 64-char event id) and reject such
// events with "invalid: unexpected size for fixed-size tag: e". All relays
// refused every check-in, so nothing was ever published.
//
// These tests pin the fixed format (full-word `emotion`/`intensity` tags)
// and the parser's tolerance for the legacy tags.

import 'package:dart_nostr/dart_nostr.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final keys = NostrKeyPairs(private: '11' * 32);

  test('signed check-in uses emotion/intensity tags, never reserved e/i', () {
    final event = CheckinEvent(
      id: '',
      pubkey: keys.public,
      emotion: Emotion.joy,
      intensity: 4,
      note: 'hello',
      geohash: 'u2e',
      createdAt: DateTime.utc(2026, 10, 22, 9),
    ).toNostrEvent(keys);

    final tags = event.tags ?? const <List<String>>[];
    bool hasTag(String name, String value) => tags.any(
      (tag) => tag.length >= 2 && tag[0] == name && tag[1] == value,
    );

    expect(hasTag('t', 'emosphere'), isTrue);
    expect(hasTag('emotion', 'joy'), isTrue);
    expect(hasTag('intensity', '4'), isTrue);
    expect(hasTag('g', 'u2e'), isTrue);

    // Reserved single-letter tags must not carry arbitrary values.
    expect(
      tags.where((tag) => tag.isNotEmpty && (tag[0] == 'e' || tag[0] == 'i')),
      isEmpty,
    );
  });

  test('parser accepts the new tags', () {
    final event = NostrEvent.fromPartialData(
      kind: CheckinEvent.kindValue,
      content: 'hi',
      keyPairs: keys,
      tags: <List<String>>[
        <String>['t', 'emosphere'],
        <String>['emotion', 'love'],
        <String>['intensity', '5'],
      ],
      createdAt: DateTime.utc(2026, 10, 22, 9),
    );
    final parsed = CheckinEvent.fromNostrEvent(event);
    expect(parsed, isNotNull);
    expect(parsed!.emotion, Emotion.love);
    expect(parsed.intensity, 5);
  });

  test('parser still reads legacy e/i tags', () {
    final event = NostrEvent.fromPartialData(
      kind: CheckinEvent.kindValue,
      content: '',
      keyPairs: keys,
      tags: <List<String>>[
        <String>['t', 'emosphere'],
        <String>['e', 'love'],
        <String>['i', '2'],
      ],
      createdAt: DateTime.utc(2026, 10, 22, 9),
    );
    final parsed = CheckinEvent.fromNostrEvent(event);
    expect(parsed, isNotNull);
    expect(parsed!.emotion, Emotion.love);
    expect(parsed.intensity, 2);
  });
}
