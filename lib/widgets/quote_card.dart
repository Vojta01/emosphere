// The reflective quote card (R11) — a frosted-glass card with the quote in
// the UI language, the attribution in the emotion colour and a hint for
// traditional attributions. Shared by the afterglow overlay (animated) and
// the check-in detail sheet in History.

import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../core/quotes/quotes.dart';

/// One quote, rendered as the glass "reflection" card.
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.s,
    required this.quote,
    required this.color,
  });

  /// UI strings (picks the CZ or EN text).
  final Strings s;

  /// The quote to show.
  final Quote quote;

  /// The emotion colour (accent bar + attribution).
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = quote.text(s.language);
    // Czech typographic quotes, straight quotes in English.
    final decorated = s.language == 'en' ? '"$text"' : '„$text“';
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 3,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  decorated,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.94),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '— ${quote.author}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                if (quote.isAttributed) ...[
                  const SizedBox(height: 4),
                  Text(
                    s.tr('quote.attributed'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.40),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
