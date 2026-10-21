// Tests for friend-key handling: npub parsing (NIP-19), validation,
// deduplication and list add/remove operations.

import 'package:emosphere/core/nostr/nip19.dart';
import 'package:emosphere/core/social/friends.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Published NIP-19 example (the same key pair used by nostr-tools docs).
  const hexKey =
      '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
  const npubKey =
      'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';

  group('decodeNpub', () {
    test('decodes a published npub into its hex pubkey', () {
      expect(decodeNpub(npubKey), hexKey);
    });

    test('accepts uppercase input (bech32 allows it)', () {
      expect(decodeNpub(npubKey.toUpperCase()), hexKey);
    });

    test('rejects mixed case', () {
      final mixed =
          'Npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
      expect(decodeNpub(mixed), isNull);
    });

    test('rejects a broken checksum', () {
      final last = npubKey.substring(npubKey.length - 1);
      final broken =
          '${npubKey.substring(0, npubKey.length - 1)}${last == 'q' ? 'p' : 'q'}';
      expect(decodeNpub(broken), isNull);
    });

    test('rejects the wrong human-readable part', () {
      expect(decodeNpub(npubKey.replaceFirst('npub1', 'nsec1')), isNull);
    });

    test('rejects empty, short and malformed input', () {
      expect(decodeNpub(''), isNull);
      expect(decodeNpub('   '), isNull);
      expect(decodeNpub('npub1'), isNull);
      expect(decodeNpub('npub1!!!'), isNull);
      expect(decodeNpub('npub1qqqqqq'), isNull);
    });
  });

  group('encodeNpub', () {
    test('encodes the published vector', () {
      expect(encodeNpub(hexKey), npubKey);
    });

    test('round-trips an all-zero key', () {
      final zero = '0' * 64;
      expect(decodeNpub(encodeNpub(zero)), zero);
    });

    test('round-trips an all-f key', () {
      final ones = 'f' * 64;
      expect(decodeNpub(encodeNpub(ones)), ones);
    });

    test('accepts uppercase hex input', () {
      expect(encodeNpub(hexKey.toUpperCase()), npubKey);
    });

    test('throws on malformed hex', () {
      expect(() => encodeNpub('xyz'), throwsArgumentError);
      expect(() => encodeNpub('abc'), throwsArgumentError);
      expect(() => encodeNpub(''), throwsArgumentError);
      expect(() => encodeNpub('0' * 63), throwsArgumentError);
    });
  });

  group('normalizePubkeyInput', () {
    test('passes through hex (lowercased)', () {
      expect(normalizePubkeyInput('  $hexKey  '), hexKey);
      expect(normalizePubkeyInput(hexKey.toUpperCase()), hexKey);
    });

    test('converts npub input to hex', () {
      expect(normalizePubkeyInput(npubKey), hexKey);
    });

    test('returns null for invalid input', () {
      expect(normalizePubkeyInput('hello'), isNull);
      expect(normalizePubkeyInput(''), isNull);
    });
  });

  group('shortenKey', () {
    test('shortens long keys with an ellipsis', () {
      expect(shortenKey(hexKey), '3bf0c63f…a459d');
    });

    test('keeps short strings unchanged', () {
      expect(shortenKey('abc'), 'abc');
    });
  });

  group('isValidNpub', () {
    test('accepts the published vector', () {
      expect(isValidNpub(npubKey), isTrue);
    });

    test('rejects a one-character mutation', () {
      expect(
        isValidNpub(
          'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6wq',
        ),
        isFalse,
      );
    });
  });

  group('dedupeFriendKeys', () {
    test('collapses npub and hex forms of the same key into hex', () {
      final deduped = dedupeFriendKeys(<String>[
        hexKey,
        npubKey, // same key in npub form
        hexKey.toUpperCase(),
        '  $hexKey  ',
        'aa${'0' * 60}',
      ]);
      expect(deduped, [hexKey, 'aa${'0' * 60}']);
    });

    test('keeps the first-seen order of distinct keys', () {
      final second = 'aa${'0' * 60}';
      expect(dedupeFriendKeys([second, npubKey]), [second, hexKey]);
    });

    test('drops blank entries', () {
      expect(dedupeFriendKeys(['', '  ', hexKey]), [hexKey]);
    });

    test('keeps unparsable entries once, lowercased', () {
      expect(dedupeFriendKeys(['Garbage', 'garbage', ' x ']), ['garbage', 'x']);
    });
  });

  group('isFriendKeyPresent', () {
    test('matches an npub input against stored hex', () {
      expect(isFriendKeyPresent([hexKey], npubKey), isTrue);
    });

    test('matches case-insensitively', () {
      expect(isFriendKeyPresent([hexKey], hexKey.toUpperCase()), isTrue);
    });

    test('returns false for unknown or invalid input', () {
      expect(isFriendKeyPresent([hexKey], 'aa${'0' * 60}'), isFalse);
      expect(isFriendKeyPresent([hexKey], 'not-a-key'), isFalse);
    });
  });

  group('addFriendKey', () {
    test('adds a valid npub as hex', () {
      final result = addFriendKey(<String>[], npubKey);
      expect(result.outcome, AddFriendOutcome.added);
      expect(result.keys, [hexKey]);
    });

    test('reports duplicates without changing the list', () {
      final result = addFriendKey([hexKey], npubKey);
      expect(result.outcome, AddFriendOutcome.duplicate);
      expect(result.keys, [hexKey]);
    });

    test('reports invalid input without changing the list', () {
      final result = addFriendKey([hexKey], 'garbage');
      expect(result.outcome, AddFriendOutcome.invalid);
      expect(result.keys, [hexKey]);
    });
  });

  group('removeFriendKey', () {
    test('removes a stored key addressed by npub', () {
      final result = removeFriendKey([hexKey, 'aa${'0' * 60}'], npubKey);
      expect(result, ['aa${'0' * 60}']);
    });

    test('keeps the list for invalid input', () {
      final result = removeFriendKey([hexKey], 'garbage');
      expect(result, [hexKey]);
    });
  });
}
