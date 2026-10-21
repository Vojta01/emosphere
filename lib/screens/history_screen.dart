import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../core/models/checkin.dart';
import '../core/models/emotion.dart';
import '../theme/app_theme.dart';

/// My check-ins: timeline + simple per-emotion statistics.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.s, required this.checkins});

  final Strings s;
  final List<CheckinEvent> checkins;

  @override
  Widget build(BuildContext context) {
    return SafeArea(child: checkins.isEmpty ? _empty() : _content());
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🌙', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 18),
            Text(
              s.tr('hist.empty'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    final counts = <Emotion, int>{};
    for (final checkin in checkins) {
      counts[checkin.emotion] = (counts[checkin.emotion] ?? 0) + 1;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
      children: [
        Text(
          s.tr('hist.title'),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        _statsCard(counts),
        const SizedBox(height: 12),
        _weekCard(),
        const SizedBox(height: 18),
        for (final checkin in checkins) ...[
          _checkinCard(checkin),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _statsCard(Map<Emotion, int> counts) {
    final total = checkins.length;
    final maxCount = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.tr('hist.total'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
              Text(
                '$total',
                key: const Key('hist_total'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final entry in sorted) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      entry.key.emoji,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  SizedBox(
                    width: 86,
                    child: Text(
                      entry.key.label(s.language),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 8,
                        color: Colors.white.withValues(alpha: 0.06),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: entry.value / maxCount,
                          child: Container(
                            color: entry.key.color.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// One column per day of the last seven days: bar height = check-in count,
  /// colour = the day's dominant emotion (weighted by intensity).
  Widget _weekCard() {
    final buckets = _lastSevenDays();
    final maxCount = buckets.fold<int>(
      1,
      (best, bucket) => bucket.count > best ? bucket.count : best,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tr('hist.last7'),
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 104,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bucket in buckets)
                  Expanded(child: _dayColumn(bucket, maxCount)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayColumn(_DayBucket bucket, int maxCount) {
    final dominant = bucket.dominant;
    final color = dominant?.color ?? Colors.white.withValues(alpha: 0.35);
    final barHeight = bucket.count == 0
        ? 4.0
        : 14 + (bucket.count / maxCount) * 44;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          bucket.count == 0 ? '' : '${bucket.count}',
          key: Key('day_count_${bucket.day.weekday}'),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: barHeight,
          width: 18,
          decoration: BoxDecoration(
            color: color.withValues(alpha: bucket.count == 0 ? 0.5 : 0.9),
            borderRadius: BorderRadius.circular(6),
            boxShadow: bucket.count == 0
                ? null
                : AppTheme.glow(color, opacity: 0.35, blur: 12, spread: 0),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _weekdayLabel(bucket.day),
          style: TextStyle(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }

  /// The seven day buckets of the current week, oldest first.
  List<_DayBucket> _lastSevenDays() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final buckets = <_DayBucket>[
      for (var offset = 6; offset >= 0; offset--)
        _DayBucket(day: today.subtract(Duration(days: offset))),
    ];
    for (final checkin in checkins) {
      final local = checkin.createdAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      for (final bucket in buckets) {
        if (bucket.day == day) {
          bucket.add(checkin);
          break;
        }
      }
    }
    return buckets;
  }

  String _weekdayLabel(DateTime day) {
    const czech = <String>['Po', 'Út', 'St', 'Čt', 'Pá', 'So', 'Ne'];
    const english = <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    final labels = s.language == 'en' ? english : czech;
    return labels[day.weekday - 1];
  }

  Widget _checkinCard(CheckinEvent checkin) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: checkin.emotion.color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: checkin.emotion.color.withValues(alpha: 0.16),
            ),
            child: Center(
              child: Text(
                checkin.emotion.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        checkin.emotion.label(s.language),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: checkin.emotion.color,
                        ),
                      ),
                    ),
                    Text(
                      _relTime(checkin.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    _intensityDots(checkin),
                    if (checkin.geohash != null &&
                        checkin.geohash!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.place,
                        size: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      Text(
                        ' ${checkin.geohash}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ],
                ),
                if (checkin.note.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  Text(
                    checkin.note,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _intensityDots(CheckinEvent checkin) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= checkin.intensity
                    ? checkin.emotion.color
                    : Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
      ],
    );
  }

  String _relTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return s.tr('hist.now');
    if (diff.inMinutes < 60) {
      return s.tr('hist.minAgo').replaceFirst('{n}', '${diff.inMinutes}');
    }
    if (diff.inHours < 24) {
      return s.tr('hist.hAgo').replaceFirst('{n}', '${diff.inHours}');
    }
    if (diff.inDays < 7) {
      return s.tr('hist.dAgo').replaceFirst('{n}', '${diff.inDays}');
    }
    return '${time.day}. ${time.month}.';
  }
}

/// Check-ins of one local day (used by the seven-day mini chart).
class _DayBucket {
  _DayBucket({required this.day});

  /// Local midnight of the day.
  final DateTime day;

  /// Check-ins published on [day].
  final List<CheckinEvent> items = <CheckinEvent>[];

  /// Number of check-ins on [day].
  int get count => items.length;

  /// The day's dominant emotion — the highest total intensity; ties fall back
  /// to the first check-in. `null` when nothing was published.
  Emotion? get dominant {
    if (items.isEmpty) {
      return null;
    }
    final weights = <Emotion, int>{};
    for (final item in items) {
      weights[item.emotion] = (weights[item.emotion] ?? 0) + item.intensity;
    }
    var best = items.first.emotion;
    var bestWeight = -1;
    for (final entry in weights.entries) {
      if (entry.value > bestWeight) {
        best = entry.key;
        bestWeight = entry.value;
      }
    }
    return best;
  }

  void add(CheckinEvent checkin) => items.add(checkin);
}
