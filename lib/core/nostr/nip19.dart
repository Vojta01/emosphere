// NIP-19 bech32 helpers for npub keys (friends flow).
//
// Deliberately dependency-free (no packages, no app imports) so the friends
// screen and its tests work in isolation and the bech32 maths stays auditable.
// Only npub is implemented for now: friends add/remove/share needs encode,
// decode and validation of public-key bech32 strings.

/// Bech32 data character set (BIP-173), index = 5-bit value.
const String _charset = 'qpzry9x8gf2tvdw0s3jn54khce6mua7l';

/// Generator constants of the BIP-173 checksum.
const List<int> _generator = <int>[
  0x3b6a57b2,
  0x26508e6d,
  0x1ea119fa,
  0x3d4233dd,
  0x2a1462b3,
];

final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

int _polymod(List<int> values) {
  var checksum = 1;
  for (final value in values) {
    final top = checksum >> 25;
    checksum = ((checksum & 0x1ffffff) << 5) ^ value;
    for (var i = 0; i < 5; i++) {
      if ((top >> i) & 1 == 1) {
        checksum ^= _generator[i];
      }
    }
  }
  return checksum;
}

List<int> _hrpExpand(String hrp) => <int>[
  for (final code in hrp.codeUnits) code >> 5,
  0,
  for (final code in hrp.codeUnits) code & 31,
];

List<int> _createChecksum(String hrp, List<int> data) {
  final polymod =
      _polymod(<int>[..._hrpExpand(hrp), ...data, 0, 0, 0, 0, 0, 0]) ^ 1;
  return <int>[for (var i = 0; i < 6; i++) (polymod >> (5 * (5 - i))) & 31];
}

bool _verifyChecksum(String hrp, List<int> data) =>
    _polymod(<int>[..._hrpExpand(hrp), ...data]) == 1;

/// Converts between bit groups (BIP-173 `convertbits`).
///
/// Returns `null` when [data] contains values that do not fit into [fromBits]
/// or when the final padding is invalid (with `pad: false`).
List<int>? _convertBits(List<int> data, int fromBits, int toBits, bool pad) {
  var accumulator = 0;
  var bits = 0;
  final result = <int>[];
  final maxValue = (1 << toBits) - 1;
  final maxAccumulator = (1 << (fromBits + toBits - 1)) - 1;
  for (final value in data) {
    if (value < 0 || value >> fromBits != 0) {
      return null;
    }
    accumulator = ((accumulator << fromBits) | value) & maxAccumulator;
    bits += fromBits;
    while (bits >= toBits) {
      bits -= toBits;
      result.add((accumulator >> bits) & maxValue);
    }
  }
  if (pad) {
    if (bits > 0) {
      result.add((accumulator << (toBits - bits)) & maxValue);
    }
  } else if (bits >= fromBits ||
      (accumulator << (toBits - bits)) & maxValue != 0) {
    return null;
  }
  return result;
}

/// Decodes an npub (NIP-19 bech32) into a 64-char lowercase hex public key.
///
/// Returns `null` when [input] is empty, mixed case, not an npub, has a broken
/// bech32 checksum, or does not carry exactly 32 bytes of key material.
String? decodeNpub(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed != trimmed.toLowerCase() && trimmed != trimmed.toUpperCase()) {
    return null; // mixed case is invalid per BIP-173
  }
  final normalized = trimmed.toLowerCase();
  final separator = normalized.lastIndexOf('1');
  if (separator != 4 || !normalized.startsWith('npub1')) {
    return null; // human-readable part must be exactly "npub"
  }
  final dataPart = normalized.substring(separator + 1);
  if (dataPart.length < 6) {
    return null; // shorter than the checksum itself
  }
  final data = <int>[];
  for (final code in dataPart.codeUnits) {
    final index = _charset.indexOf(String.fromCharCode(code));
    if (index < 0) {
      return null;
    }
    data.add(index);
  }
  if (!_verifyChecksum('npub', data)) {
    return null;
  }
  final bytes = _convertBits(data.sublist(0, data.length - 6), 5, 8, false);
  if (bytes == null || bytes.length != 32) {
    return null;
  }
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

/// Encodes a 64-char hex public key as an npub (NIP-19 bech32).
///
/// Throws [ArgumentError] when [hexPubkey] is not a 64-char hex string.
String encodeNpub(String hexPubkey) {
  final normalized = hexPubkey.trim().toLowerCase();
  if (!_hex64.hasMatch(normalized)) {
    throw ArgumentError.value(hexPubkey, 'hexPubkey', 'must be 64 hex chars');
  }
  final bytes = <int>[
    for (var i = 0; i < normalized.length; i += 2)
      int.parse(normalized.substring(i, i + 2), radix: 16),
  ];
  final words = _convertBits(bytes, 8, 5, true)!;
  final payload = <int>[...words, ..._createChecksum('npub', words)];
  return 'npub1${payload.map((word) => _charset[word]).join()}';
}

/// True when [input] is a structurally valid npub with a correct checksum.
bool isValidNpub(String input) => decodeNpub(input) != null;

/// Normalizes user input (npub or 64-char hex) to a lowercase hex pubkey.
///
/// Returns `null` for anything else so callers can show a validation error.
String? normalizePubkeyInput(String input) {
  final trimmed = input.trim().toLowerCase();
  if (_hex64.hasMatch(trimmed)) {
    return trimmed;
  }
  return decodeNpub(trimmed);
}

/// Shortens a key for compact display: `3bf0c63f…a459d`.
String shortenKey(String key, {int head = 8, int tail = 5}) {
  final trimmed = key.trim();
  if (trimmed.length <= head + tail) {
    return trimmed;
  }
  return '${trimmed.substring(0, head)}…'
      '${trimmed.substring(trimmed.length - tail)}';
}
