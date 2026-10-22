// NIP-04 tests — reference vectors generated with an independent Python
// implementation (coincurve + pyca/cryptography) and cross-checked for the
// ECDH symmetry property.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:emosphere/core/nostr/nip04.dart';

/// Deterministic key pair A (private + x-only public).
const String aPriv =
    '6686f5a04595532711d7c60cbd62637a0b6f8d81db21f5774efb4070fe4c94e3';
const String aPub =
    '5812d33b8d6036b011c81cbd9b84dcb1ca7d209074d3340b0f6ac2a6e387eb70';

/// Deterministic key pair B.
const String bPriv =
    '6f6f6adf5b262aaddcf3c2d475f6d8778e1e5a9c1de8148a2e4e84513447642f';
const String bPub =
    'f0d03b4254e05263d8ca5584903989433f53516ca0908edb7c6a8e56df6611ff';

/// A third key that must never read A <-> B traffic.
const String cPriv =
    '076b40e122969e6eeb2cf1ea53fdcc13cb768e448544fe83d38ff45a8a62be2c';

/// A -> B, IV 000102…0f.
const String c1 =
    'RbYG6sBV1/8lIHi/YrbDREWWn6vWhM21fXdsBdOYTJE=?iv=AAECAwQFBgcICQoLDA0ODw==';
const String msg1 = 'Ahoj z EmoSphere 👋';

/// B -> A, IV 0f0e…00.
const String c2 = 's9ZZ27quKjGffIfH0nEA8w==?iv=Dw4NDAsKCQgHBgUEAwIBAA==';
const String msg2 = 'Reply OK ✓';

void main() {
  group('Nip04', () {
    test('decrypts the reference vector A -> B', () {
      expect(
        Nip04.decrypt(
          recipientPrivateHex: bPriv,
          senderPubkeyHex: aPub,
          content: c1,
        ),
        msg1,
      );
    });

    test('decrypts the reference vector B -> A', () {
      expect(
        Nip04.decrypt(
          recipientPrivateHex: aPriv,
          senderPubkeyHex: bPub,
          content: c2,
        ),
        msg2,
      );
    });

    test('encrypts the reference vector byte for byte (fixed IV)', () {
      final encrypted = Nip04.encrypt(
        senderPrivateHex: aPriv,
        recipientPubkeyHex: bPub,
        plaintext: msg1,
        iv: Uint8List.fromList(
          const <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        ),
      );
      expect(encrypted, c1);
    });

    test('shared secret is 32 bytes and symmetric', () {
      final ab = Nip04.sharedSecret(aPriv, bPub);
      final ba = Nip04.sharedSecret(bPriv, aPub);
      expect(ab.length, 32);
      expect(ab, ba);
    });

    test('round-trips with a random IV in both directions', () {
      final encrypted = Nip04.encrypt(
        senderPrivateHex: aPriv,
        recipientPubkeyHex: bPub,
        plaintext: 'Roundtrip — ěščřžýáíé ✓',
      );
      expect(
        Nip04.decrypt(
          recipientPrivateHex: bPriv,
          senderPubkeyHex: aPub,
          content: encrypted,
        ),
        'Roundtrip — ěščřžýáíé ✓',
      );

      final reply = Nip04.encrypt(
        senderPrivateHex: bPriv,
        recipientPubkeyHex: aPub,
        plaintext: 'Reply with emoji 🚀🎉',
      );
      expect(
        Nip04.decrypt(
          recipientPrivateHex: aPriv,
          senderPubkeyHex: bPub,
          content: reply,
        ),
        'Reply with emoji 🚀🎉',
      );
    });

    test('returns null for malformed content', () {
      expect(
        Nip04.decrypt(
          recipientPrivateHex: bPriv,
          senderPubkeyHex: aPub,
          content: 'not-a-nip04-payload',
        ),
        isNull,
      );
      expect(
        Nip04.decrypt(
          recipientPrivateHex: bPriv,
          senderPubkeyHex: aPub,
          content: 'AAAA?iv=BBBB',
        ),
        isNull,
      );
    });

    test('a third key cannot read the message', () {
      // Fixed IV keeps the failure deterministic (the padding check rejects
      // the wrong secret — verified against the Python reference).
      final encrypted = Nip04.encrypt(
        senderPrivateHex: aPriv,
        recipientPubkeyHex: bPub,
        plaintext: 'secret',
        iv: Uint8List.fromList(
          const <int>[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
        ),
      );
      expect(
        Nip04.decrypt(
          recipientPrivateHex: cPriv,
          senderPubkeyHex: bPub,
          content: encrypted,
        ),
        isNull,
      );
    });

    test('reference ciphertext is plain base64 + iv payload', () {
      final parts = c1.split('?iv=');
      expect(parts.length, 2);
      expect(base64.decode(parts[0]).length % 16, 0);
      expect(base64.decode(parts[1]).length, 16);
    });
  });

  group('invalid public keys', () {
    // x = 5: x³ + 7 = 132 is a quadratic non-residue mod p, so no secp256k1
    // point has this x (checked with an independent Python script).
    const String offCurve =
        '0000000000000000000000000000000000000000000000000000000000000005';

    test('sharedSecret rejects an x that is not on the curve', () {
      expect(() => Nip04.sharedSecret(aPriv, offCurve), throwsFormatException);
    });

    test('sharedSecret rejects x = 0 and x >= p', () {
      const String zero =
          '0000000000000000000000000000000000000000000000000000000000000000';
      // p itself — the field prime, one above the largest valid x.
      const String prime =
          'fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f';
      expect(() => Nip04.sharedSecret(aPriv, zero), throwsFormatException);
      expect(() => Nip04.sharedSecret(aPriv, prime), throwsFormatException);
    });

    test('decrypt returns null for an off-curve sender key', () {
      expect(
        Nip04.decrypt(
          recipientPrivateHex: bPriv,
          senderPubkeyHex: offCurve,
          content: c1,
        ),
        isNull,
      );
    });
  });
}
