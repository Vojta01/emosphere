// Check-in detail (R11) — opened from the History timeline: the check-in's
// emotion, intensity, place and note, plus a reflective quote for the
// emotion (one of the 20 in `assets/quotes.json`). The quote is picked at
// random on every opening, matching the afterglow behaviour.

import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../core/models/checkin.dart';
import '../core/quotes/quotes.dart';
import '../theme/app_theme.dart';
import 'intensity_dots.dart';
import 'quote_card.dart';

/// Opens the check-in detail sheet for [checkin].
Future<void> showCheckinDetailSheet(
  BuildContext context, {
  required Strings s,
  required CheckinEvent checkin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    isScrollControlled: true,
    builder: (_) => CheckinDetailSheet(s: s, checkin: checkin),
  );
}

/// Bottom sheet with one check-in and a reflective quote for its emotion.
class CheckinDetailSheet extends StatelessWidget {
  const CheckinDetailSheet({
    super.key,
    required this.s,
    required this.checkin,
  });

  /// UI strings.
  final Strings s;

  /// The check-in to show.
  final CheckinEvent checkin;

  @override
  Widget build(BuildContext context) {
    final emotion = checkin.emotion;
    final geohash = checkin.geohash;
    // Missing library (asset failed to load) simply hides the quote.
    final quote = QuotesLibrary.instance?.randomFor(emotion);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: AppTheme.glassDecoration(
          radius: 26,
          tint: AppTheme.surfaceHigh,
          opacity: 0.98,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: emotion.color.withValues(alpha: 0.16),
                  ),
                  child: Center(
                    child: Text(
                      emotion.emoji,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emotion.label(s.language),
                        key: const Key('detail_emotion'),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: emotion.color,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        s.timeAgo(checkin.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                IntensityDots(
                  intensity: checkin.intensity,
                  color: emotion.color,
                  dotSize: 9,
                ),
                if (geohash != null && geohash.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Icons.place,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    geohash,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ],
            ),
            if (checkin.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                checkin.note,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
            ],
            if (quote != null) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 13,
                    color: emotion.color.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      s.tr('hist.reflection'),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.4,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              QuoteCard(
                key: const Key('history_quote'),
                s: s,
                quote: quote,
                color: emotion.color,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
