// Nostr profile metadata (kind 0 / NIP-01 "set_metadata").

import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

/// Metadata of a Nostr account, parsed from a kind 0 event.
class NostrProfile {
  const NostrProfile({
    required this.pubkey,
    this.name,
    this.displayName,
    this.about,
    this.picture,
    this.nip05,
    this.updatedAt,
  });

  /// Author public key (64 hex chars).
  final String pubkey;

  /// `name` field of the metadata.
  final String? name;

  /// `display_name` field of the metadata.
  final String? displayName;

  /// `about` field of the metadata.
  final String? about;

  /// `picture` (avatar URL) field of the metadata.
  final String? picture;

  /// `nip05` identifier.
  final String? nip05;

  /// When the metadata event was created.
  final DateTime? updatedAt;

  /// Best available human name: display name, then name, then short pubkey.
  String get bestName {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) {
      return display;
    }
    final plain = name?.trim();
    if (plain != null && plain.isNotEmpty) {
      return plain;
    }
    return shortPubkey;
  }

  /// Abbreviated pubkey, e.g. `cc1fc47a…1a5e`.
  String get shortPubkey {
    if (pubkey.length <= 12) {
      return pubkey;
    }
    return '${pubkey.substring(0, 8)}…${pubkey.substring(pubkey.length - 4)}';
  }

  /// Parses metadata from a kind 0 [event]. Returns `null` when the content
  /// is not a JSON object.
  static NostrProfile? fromEvent(NostrEvent event) {
    if (event.kind != 0) {
      return null;
    }
    final raw = event.content;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      String? str(String key) {
        final value = decoded[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
        return null;
      }

      return NostrProfile(
        pubkey: event.pubkey,
        name: str('name'),
        displayName: str('display_name'),
        about: str('about'),
        picture: str('picture'),
        nip05: str('nip05'),
        updatedAt: event.createdAt?.toUtc(),
      );
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'NostrProfile($pubkey, $bestName)';
}
