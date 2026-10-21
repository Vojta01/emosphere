// Tests for the feed ordering / filtering helpers (card 3).

import 'package:emosphere/core/feed/feed_logic.dart';
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:flutter_test/flutter_test.dart';

CheckinEvent checkin(
  String pubkey,
  DateTime createdAt, {
  Emotion emotion = Emotion.joy,
  int intensity = 3,
  String note = '',
  String? geohash,
}) {
  return CheckinEvent(
    id: 'id-${pubkey.substring(0, 4)}-${createdAt.microsecondsSinceEpoch}',
    pubkey: pubkey,
    emotion: emotion,
    intensity: intensity,
    note: note,
    geohash: geohash,
    createdAt: createdAt,
  );
}

void main() {
  final base = DateTime.utc(2026, 10, 21, 12);
  const alice =
      'aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11aa11';
  const bob =
      'bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22bb22';
  const carol =
      'cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33cc33';

  group('sortByNewest', () {
    test('orders newest first regardless of input order', () {
      final events = [
        checkin(alice, base),
        checkin(bob, base.add(const Duration(hours: 2))),
        checkin(carol, base.subtract(const Duration(hours: 1))),
      ];
      final sorted = sortByNewest(events);
      expect(sorted.map((e) => e.pubkey), [bob, alice, carol]);
    });

    test('is deterministic for equal timestamps (by id, descending)', () {
      final a = checkin(alice, base);
      final b = checkin(bob, base);
      final first = sortByNewest([a, b]).map((e) => e.id).toList();
      final second = sortByNewest([b, a]).map((e) => e.id).toList();
      expect(first, second);
      // Sorted by id descending: 'id-bb22…' before 'id-aa11…'.
      expect(first, [b.id, a.id]);
    });

    test('handles an empty input', () {
      expect(sortByNewest(<CheckinEvent>[]), isEmpty);
    });
  });

  group('filterByAuthors', () {
    test('keeps only the requested authors, case-insensitive', () {
      final events = [
        checkin(alice, base),
        checkin(bob, base),
        checkin(carol, base),
      ];
      final filtered = filterByAuthors(events, [alice.toUpperCase(), carol]);
      expect(filtered.map((e) => e.pubkey), [alice, carol]);
    });

    test('returns an empty list for an empty author set', () {
      expect(filterByAuthors([checkin(alice, base)], const []), isEmpty);
    });
  });

  group('latestPerAuthor', () {
    test('keeps only the newest check-in of each author', () {
      final events = [
        checkin(alice, base),
        checkin(alice, base.add(const Duration(minutes: 30))),
        checkin(bob, base.add(const Duration(hours: 1))),
      ];
      final latest = latestPerAuthor(events);
      expect(latest.length, 2);
      expect(latest.first.pubkey, bob);
      expect(latest.last.createdAt, base.add(const Duration(minutes: 30)));
    });

    test('uses the id as tie-breaker for identical timestamps', () {
      final olderId = checkin(alice, base);
      final newerId = CheckinEvent(
        id: 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
        pubkey: alice,
        emotion: Emotion.calm,
        intensity: 1,
        createdAt: base,
      );
      final latest = latestPerAuthor([olderId, newerId]);
      expect(latest.single.id, newerId.id);
    });
  });

  group('worldFeed', () {
    test('excludes the signed-in user and caps at the limit', () {
      final events = [
        for (var i = 0; i < 3; i++)
          checkin(alice, base.add(Duration(minutes: i))),
        for (var i = 0; i < 4; i++)
          checkin(bob, base.add(Duration(minutes: 10 + i))),
      ];
      final feed = worldFeed(events, excludePubkey: alice, limit: 2);
      expect(feed.length, 2);
      expect(feed.every((e) => e.pubkey == bob), isTrue);
    });

    test('returns everything (sorted) when under the limit', () {
      final events = [
        checkin(alice, base),
        checkin(bob, base.add(const Duration(minutes: 5))),
      ];
      final feed = worldFeed(events, limit: worldFeedLimit);
      expect(feed.map((e) => e.pubkey), [bob, alice]);
    });
  });

  group('friendsFeed', () {
    test('shows the latest check-in per friend, newest first', () {
      final events = [
        checkin(alice, base.add(const Duration(hours: 3))),
        checkin(bob, base.add(const Duration(hours: 1))),
        checkin(carol, base.add(const Duration(hours: 4))),
        checkin(alice, base.add(const Duration(hours: 2))),
      ];
      final feed = friendsFeed(events, [alice, bob]);
      expect(feed.map((e) => e.pubkey), [alice, bob]);
      expect(feed.first.createdAt, base.add(const Duration(hours: 3)));
    });

    test('returns nothing when no friend has a check-in', () {
      final events = [checkin(carol, base)];
      expect(friendsFeed(events, [alice, bob]), isEmpty);
    });
  });

  group('checkinPool', () {
    test('merges world and friend check-ins, newest first', () {
      final shared = checkin(bob, base.add(const Duration(hours: 1)));
      final pool = checkinPool(
        [checkin(alice, base), shared],
        [shared, checkin(carol, base.add(const Duration(hours: 2)))],
      );
      expect(pool.map((e) => e.pubkey), [carol, bob, alice]);
    });

    test('keeps a single copy of an event that is in both lists', () {
      final world = CheckinEvent(
        id: 'same-id',
        pubkey: bob,
        emotion: Emotion.joy,
        intensity: 3,
        createdAt: base,
      );
      final friend = CheckinEvent(
        id: 'same-id',
        pubkey: bob,
        emotion: Emotion.joy,
        intensity: 4,
        note: 'ahoj',
        createdAt: base,
      );
      final pool = checkinPool([world], [friend]);
      expect(pool, hasLength(1));
      // The friend query carries the freshest copy of the event.
      expect(pool.single.intensity, 4);
      expect(pool.single.note, 'ahoj');
    });

    test('works with either side empty', () {
      final only = checkin(alice, base);
      expect(
        checkinPool(const <CheckinEvent>[], const <CheckinEvent>[]),
        isEmpty,
      );
      expect(checkinPool([only], const <CheckinEvent>[]).single.id, only.id);
      expect(checkinPool(const <CheckinEvent>[], [only]).single.id, only.id);
    });

    test('is the source for the world feed and the friends section', () {
      final friendCheckin = checkin(
        alice,
        base.add(const Duration(minutes: 5)),
      );
      final pool = checkinPool(
        [
          checkin(bob, base),
          checkin(carol, base.add(const Duration(minutes: 9))),
        ],
        [friendCheckin],
      );
      expect(worldFeed(pool, limit: 2).map((e) => e.pubkey), [carol, alice]);
      expect(friendsFeed(pool, [alice]).single.id, friendCheckin.id);
    });
  });
}
