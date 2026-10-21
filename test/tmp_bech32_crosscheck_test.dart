// TEMP dev-only cross-check — DELETED before commit.
// Verifies our npub implementation against package:bech32 (the library that
// dart_nostr itself wraps).

import 'package:bech32/bech32.dart';
import 'package:emosphere/core/nostr/nip19.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> _convert(List<int> data, int from, int to, bool pad) {
  var acc = 0;
  var bits = 0;
  final out = <int>[];
  final maxv = (1 << to) - 1;
  for (final value in data) {
    acc = ((acc << from) | value);
    bits += from;
    while (bits >= to) {
      bits -= to;
      out.add((acc >> bits) & maxv);
    }
  }
  if (pad && bits > 0) {
    out.add((acc << (to - bits)) & maxv);
  }
  return out;
}

void main() {
  test('cross-check against package:bech32', () {
    const hexKey =
        '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
    final bytes = <int>[
      for (var i = 0; i < hexKey.length; i += 2)
        int.parse(hexKey.substring(i, i + 2), radix: 16),
    ];
    final words = _convert(bytes, 8, 5, true);
    final reference = const Bech32Codec().encode(Bech32('npub', words), 100);
    // ignore: avoid_print
    print('package:bech32 -> $reference');
    // ignore: avoid_print
    print('ours           -> ${encodeNpub(hexKey)}');
    expect(encodeNpub(hexKey), reference);
    expect(decodeNpub(reference), hexKey);

    // Random-ish second vector.
    const other =
        'cc1fc47a3e5f8e2b6d90aa4c2f7b1e8d5a6c3b2f1e0d9c8b7a6f5e4d3c2b1a09';
    final otherBytes = <int>[
      for (var i = 0; i < other.length; i += 2)
        int.parse(other.substring(i, i + 2), radix: 16),
    ];
    final otherRef = const Bech32Codec().encode(
      Bech32('npub', _convert(otherBytes, 8, 5, true)),
      100,
    );
    expect(encodeNpub(other), otherRef);
    expect(decodeNpub(otherRef), other);
    // ignore: avoid_print
    print('vector2 ours   -> ${encodeNpub(other)}');
  });
}
