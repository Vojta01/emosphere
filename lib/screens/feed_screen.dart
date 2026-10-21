// Feed screen — "Right now in the world".
//
// Minimal scaffold so the core (card 1) compiles end-to-end; card 2/3 extends
// it (friends section, profile names, pull-to-refresh, animations).

import 'package:flutter/material.dart';

import '../core/feed/feed_logic.dart';
import '../core/i18n/strings.dart';
import '../core/models/checkin.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// The world feed: the newest check-ins from all relays.
class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.app});

  /// Application state (world check-ins live here).
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: app,
        builder: (context, _) {
          final s = Strings(app.language);
          final feed = sortByNewest(app.worldCheckins)
              .take(worldFeedLimit)
              .toList();
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            onRefresh: app.refresh,
            child: feed.isEmpty ? _empty(s) : _list(s, feed),
          );
        },
      ),
    );
  }

  Widget _empty(Strings s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 170),
      children: [
        const Center(child: Text('🌍', style: TextStyle(fontSize: 56))),
        const SizedBox(height: 18),
        Text(
          s.tr('worldSection'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          s.tr('feedEmpty'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _list(Strings s, List<CheckinEvent> feed) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
      itemCount: feed.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              s.tr('worldSection'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CheckinTile(checkin: feed[index - 1], s: s),
        );
      },
    );
  }
}

/// One feed card: emotion colour, label, relative time, note, intensity.
class _CheckinTile extends StatelessWidget {
  const _CheckinTile({required this.checkin, required this.s});

  final CheckinEvent checkin;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final emotion = checkin.emotion;
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emotion.color.withValues(alpha: 0.16),
              border: Border.all(color: emotion.color.withValues(alpha: 0.5)),
            ),
            child: Text(emotion.emoji, style: const TextStyle(fontSize: 20)),
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
                        emotion.label(s.language),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: emotion.color,
                        ),
                      ),
                    ),
                    Text(
                      s.timeAgo(checkin.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(right: 3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i <= checkin.intensity
                              ? emotion.color.withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    if (checkin.geohash != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.place_outlined,
                        size: 12,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      Text(
                        checkin.geohash!,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                      ),
                    ],
                  ],
                ),
                if (checkin.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    checkin.note,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.85),
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
}
