// Offline [NostrService] stand-in for widget tests (card 3/7).
//
// The map and feed screens read everything from [AppState], which in turn only
// talks to [NostrService]. Answering the service from in-memory lists keeps the
// screens under test while no relay, socket or secure storage is involved.
//
// `pubkeyHex` / `npub` are overridable getters, so a test can pretend that the
// running app already owns an identity (the screens exclude the user's own
// check-ins from the world feed with it).

import 'package:emosphere/core/feed/feed_logic.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/profile.dart';
import 'package:emosphere/core/nostr/nip19.dart';
import 'package:emosphere/core/nostr/nostr_service.dart';

/// A [NostrService] that answers from memory and never opens a socket.
class FakeRelayService extends NostrService {
  FakeRelayService({
    this.mine = const <CheckinEvent>[],
    this.world = const <CheckinEvent>[],
    this.profiles = const <String, NostrProfile>{},
    this.pubkeyHex,
  }) : super(relays: const <String>['wss://fake.relay']);

  /// Check-ins returned by [fetchMyCheckins].
  final List<CheckinEvent> mine;

  /// Check-ins returned by [fetchCheckins] (author-filtered on request).
  final List<CheckinEvent> world;

  /// Kind 0 metadata answered per pubkey.
  final Map<String, NostrProfile> profiles;

  /// Hex pubkey this fake pretends to be signed in with (`null` = no identity).
  @override
  final String? pubkeyHex;

  /// Number of check-in queries answered (used to assert a refresh happened).
  int fetchCheckinsCalls = 0;

  /// Number of profile queries answered.
  int fetchProfilesCalls = 0;

  @override
  bool get hasIdentity => pubkeyHex != null;

  @override
  String? get npub => pubkeyHex == null ? null : encodeNpub(pubkeyHex!);

  @override
  String? get nsec => null;

  @override
  Future<List<CheckinEvent>> fetchCheckins({
    DateTime? since,
    List<String>? authors,
    int? limit,
    Duration? timeout,
  }) async {
    fetchCheckinsCalls++;
    final filtered = (authors == null || authors.isEmpty)
        ? world
        : filterByAuthors(world, authors);
    final sorted = sortByNewest(filtered);
    if (limit == null || limit < 0 || sorted.length <= limit) {
      return sorted;
    }
    return sorted.sublist(0, limit);
  }

  @override
  Future<List<CheckinEvent>> fetchMyCheckins({int limit = 200}) async {
    final sorted = sortByNewest(mine);
    if (sorted.length <= limit) {
      return sorted;
    }
    return sorted.sublist(0, limit);
  }

  @override
  Future<Map<String, NostrProfile>> fetchProfiles(
    Iterable<String> pubkeys, {
    Duration? timeout,
  }) async {
    fetchProfilesCalls++;
    final wanted = <String>{
      for (final key in pubkeys) key.trim().toLowerCase(),
    };
    return <String, NostrProfile>{
      for (final entry in profiles.entries)
        if (wanted.contains(entry.key.trim().toLowerCase()))
          entry.key.trim().toLowerCase(): entry.value,
    };
  }

  @override
  Stream<CheckinEvent> subscribeCheckins({
    DateTime? since,
    List<String>? authors,
    int? limit,
  }) => const Stream<CheckinEvent>.empty();
}
