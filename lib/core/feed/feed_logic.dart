// Feed ordering and filtering helpers.
//
// Pure functions over [CheckinEvent] lists so the feed screen (and its tests)
// stay independent of snapshot or refresh plumbing in the app state.

import '../models/checkin.dart';

/// Maximum number of check-ins shown in the "right now in the world" feed.
const int worldFeedLimit = 50;

/// Sorts [events] newest first.
///
/// Timestamps of equal value are ordered by event id (descending) so the
/// result is deterministic for any input order.
List<CheckinEvent> sortByNewest(Iterable<CheckinEvent> events) {
  final result = List<CheckinEvent>.of(events);
  result.sort((a, b) {
    final byTime = b.createdAt.compareTo(a.createdAt);
    if (byTime != 0) {
      return byTime;
    }
    return b.id.compareTo(a.id);
  });
  return result;
}

/// Returns only the events authored by one of [pubkeys] (case-insensitive).
List<CheckinEvent> filterByAuthors(
  Iterable<CheckinEvent> events,
  Iterable<String> pubkeys,
) {
  final wanted = <String>{for (final key in pubkeys) key.trim().toLowerCase()};
  if (wanted.isEmpty) {
    return <CheckinEvent>[];
  }
  return <CheckinEvent>[
    for (final event in events)
      if (wanted.contains(event.pubkey.toLowerCase())) event,
  ];
}

/// Merges the world stream with the check-ins of my friends.
///
/// Deduplicated by event id (a friend's check-in is normally part of the world
/// stream too) and sorted newest first. This is the pool the world feed, the
/// friends section and the map heat layer work on.
List<CheckinEvent> checkinPool(
  Iterable<CheckinEvent> world,
  Iterable<CheckinEvent> friends,
) {
  final byId = <String, CheckinEvent>{};
  for (final event in world) {
    byId[event.id] = event;
  }
  for (final event in friends) {
    byId[event.id] = event;
  }
  return sortByNewest(byId.values);
}

/// Returns the newest check-in of every author, newest first.
List<CheckinEvent> latestPerAuthor(Iterable<CheckinEvent> events) {
  final newest = <String, CheckinEvent>{};
  for (final event in events) {
    final key = event.pubkey.toLowerCase();
    final current = newest[key];
    if (current == null || _isNewer(event, current)) {
      newest[key] = event;
    }
  }
  return sortByNewest(newest.values);
}

bool _isNewer(CheckinEvent candidate, CheckinEvent current) {
  final byTime = candidate.createdAt.compareTo(current.createdAt);
  if (byTime != 0) {
    return byTime > 0;
  }
  return candidate.id.compareTo(current.id) > 0;
}

/// "Right now in the world": the newest [limit] check-ins.
///
/// The signed-in user's own check-ins are excluded when [excludePubkey] is
/// given (they belong in the personal history, not the world stream).
List<CheckinEvent> worldFeed(
  Iterable<CheckinEvent> events, {
  String? excludePubkey,
  int limit = worldFeedLimit,
}) {
  final excluded = excludePubkey?.trim().toLowerCase();
  final sorted = sortByNewest(
    excluded == null || excluded.isEmpty
        ? events
        : events.where((event) => event.pubkey.toLowerCase() != excluded),
  );
  if (limit < 0 || sorted.length <= limit) {
    return sorted;
  }
  return sorted.sublist(0, limit);
}

/// "My close ones": the latest check-in of each friend, newest first.
List<CheckinEvent> friendsFeed(
  Iterable<CheckinEvent> events,
  Iterable<String> friendPubkeys, {
  int limit = worldFeedLimit,
}) {
  final result = latestPerAuthor(filterByAuthors(events, friendPubkeys));
  if (limit < 0 || result.length <= limit) {
    return result;
  }
  return result.sublist(0, limit);
}
