// Friend-list helpers (feed/friends work).
//
// Pure functions over hex public keys so the friends screen stays testable
// without the network or the app state: parse user input, deduplicate, and
// apply add/remove operations.

import '../nostr/nip19.dart';

/// Result of trying to add a friend key to a list.
enum AddFriendOutcome {
  /// Key was valid and has been appended.
  added,

  /// Key was valid but already present.
  duplicate,

  /// Input was not a valid npub or hex key.
  invalid,
}

/// Outcome plus the (possibly unchanged) friend-key list.
class AddFriendResult {
  const AddFriendResult(this.outcome, this.keys);

  /// What happened.
  final AddFriendOutcome outcome;

  /// The resulting key list (lowercase hex, deduplicated, order-preserving).
  final List<String> keys;
}

/// Normalizes [input] to a hex pubkey when it is a valid npub or hex key.
///
/// Returns `null` for empty, malformed or checksum-broken input.
String? parseFriendInput(String input) => normalizePubkeyInput(input);

/// Removes duplicates (case-insensitive) while keeping first-seen order.
///
/// Blank entries are dropped.
List<String> dedupeFriendKeys(Iterable<String> keys) {
  final seen = <String>{};
  final result = <String>[];
  for (final key in keys) {
    final normalized = key.trim().toLowerCase();
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    result.add(normalized);
  }
  return result;
}

/// True when [candidate] (npub or hex) equals an entry of [existing].
bool isFriendKeyPresent(Iterable<String> existing, String candidate) {
  final normalized = parseFriendInput(candidate);
  if (normalized == null) {
    return false;
  }
  return existing.any((key) => key.trim().toLowerCase() == normalized);
}

/// Adds [input] to [existing] when it parses and is not present yet.
AddFriendResult addFriendKey(List<String> existing, String input) {
  final normalized = parseFriendInput(input);
  if (normalized == null) {
    return AddFriendResult(AddFriendOutcome.invalid, existing);
  }
  if (existing.any((key) => key.trim().toLowerCase() == normalized)) {
    return AddFriendResult(AddFriendOutcome.duplicate, existing);
  }
  return AddFriendResult(AddFriendOutcome.added, <String>[
    ...existing,
    normalized,
  ]);
}

/// Removes [input] (npub or hex) from [existing]; returns the new list.
List<String> removeFriendKey(List<String> existing, String input) {
  final normalized = parseFriendInput(input);
  if (normalized == null) {
    return existing;
  }
  return <String>[
    for (final key in existing)
      if (key.trim().toLowerCase() != normalized) key,
  ];
}
