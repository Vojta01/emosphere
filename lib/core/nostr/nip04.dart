// NIP-04 encrypted direct messages — AES-256-CBC over a secp256k1 ECDH
// shared secret.
//
// Wire format of the event content: `base64(ciphertext)?iv=base64(iv)`.
// The AES key is the raw X coordinate of `private * point(pubkey)` (the
// pubkey is an x-only BIP-340 key, lifted with an even Y). The same secret
// comes out of both directions, so a message can be decrypted by either
// party with their own private key and the counterparty's public key.
//
// The event content is encrypted end to end; NIP-04 keeps the routing
// metadata (who writes to whom, the `p` tag) public — see ARCHITECTURE.md.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// NIP-04 crypto helpers.
class Nip04 {
  Nip04._();

  /// Encrypts [plaintext] from [senderPrivateHex] to [recipientPubkeyHex].
  ///
  /// Returns the NIP-04 content string. [iv] exists for deterministic tests;
  /// production always passes `null` and gets a fresh random IV.
  static String encrypt({
    required String senderPrivateHex,
    required String recipientPubkeyHex,
    required String plaintext,
    Uint8List? iv,
  }) {
    final key = sharedSecret(senderPrivateHex, recipientPubkeyHex);
    final nonce = iv ?? _randomBytes(16);
    final cipher = _cipher(forEncryption: true, key: key, iv: nonce);
    final encrypted = cipher.process(
      Uint8List.fromList(utf8.encode(plaintext)),
    );
    return '${base64Encode(encrypted)}?iv=${base64Encode(nonce)}';
  }

  /// Decrypts a NIP-04 [content] that [senderPubkeyHex] sent to the holder of
  /// [recipientPrivateHex]. Returns `null` when the payload cannot be read
  /// (malformed content, wrong key, tampered data).
  static String? decrypt({
    required String recipientPrivateHex,
    required String senderPubkeyHex,
    required String content,
  }) {
    try {
      final separator = content.indexOf('?iv=');
      if (separator <= 0) {
        return null;
      }
      final encrypted = base64Decode(content.substring(0, separator));
      final iv = base64Decode(content.substring(separator + 4));
      final key = sharedSecret(recipientPrivateHex, senderPubkeyHex);
      final cipher = _cipher(forEncryption: false, key: key, iv: iv);
      final decrypted = cipher.process(encrypted);
      return utf8.decode(decrypted);
    } on Object {
      return null;
    }
  }

  /// Raw ECDH shared secret: the 32-byte X coordinate of
  /// `private * point(pubkey)`. Symmetric, so both parties derive the same
  /// key.
  static Uint8List sharedSecret(String privateHex, String pubkeyHex) {
    final curve = ECCurve_secp256k1();
    final d = BigInt.parse(privateHex, radix: 16);
    final q = _pointFromX(pubkeyHex, curve.curve);
    final agreement = ECDHBasicAgreement()..init(ECPrivateKey(d, curve));
    final secret = agreement.calculateAgreement(ECPublicKey(q, curve));
    return _to32Bytes(secret);
  }

  /// Rebuilds a secp256k1 point from an x-only (BIP-340) public key,
  /// choosing the even Y — the same lift every Nostr implementation uses.
  ///
  /// Throws [FormatException] when the key cannot lie on the curve: `x` must
  /// be a field element (`0 < x < p`) and `x³ + 7` a quadratic residue.
  /// Without these checks `curve.createPoint` would silently accept a point
  /// that is not on the curve and yield a garbage shared secret.
  static ECPoint _pointFromX(String pubkeyHex, ECCurve curve) {
    final x = BigInt.tryParse(pubkeyHex, radix: 16);
    // Field prime of secp256k1: 2^256 - 2^32 - 977.
    final p = (BigInt.one << 256) - (BigInt.one << 32) - BigInt.from(977);
    if (x == null || x <= BigInt.zero || x >= p) {
      throw const FormatException('Public key is not a field element.');
    }
    final alpha = (x.modPow(BigInt.from(3), p) + BigInt.from(7)) % p;
    // p % 4 == 3, so the square root is alpha^((p+1)/4).
    final beta = alpha.modPow((p + BigInt.one) >> 2, p);
    if ((beta * beta) % p != alpha) {
      throw const FormatException('Public key is not on the curve.');
    }
    final y = beta.isEven ? beta : p - beta;
    return curve.createPoint(x, y);
  }

  static PaddedBlockCipherImpl _cipher({
    required bool forEncryption,
    required Uint8List key,
    required Uint8List iv,
  }) {
    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      forEncryption,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
        null,
      ),
    );
    return cipher;
  }

  /// Big-endian 32-byte encoding of [value].
  static Uint8List _to32Bytes(BigInt value) {
    final bytes = Uint8List(32);
    var v = value;
    for (var i = 31; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xff)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => random.nextInt(256)),
    );
  }
}
