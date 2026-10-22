// Shared round avatar: the kind 0 `picture`, otherwise a coloured initial.

import 'package:flutter/material.dart';

import '../core/models/profile.dart';
import '../theme/app_theme.dart';

/// Round avatar of an author (used by the feed, the user sheet and the
/// messages screens).
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.profile,
    required this.pubkey,
    this.radius = 16,
  });

  final NostrProfile? profile;
  final String pubkey;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final picture = profile?.picture;
    final fallback = _initial();
    if (picture == null || picture.isEmpty) {
      return fallback;
    }
    return ClipOval(
      child: Image.network(
        picture,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // Offline or a broken URL must not break the card.
        errorBuilder: (context, error, stackTrace) => fallback,
      ),
    );
  }

  Widget _initial() {
    final name = profile?.bestName ?? pubkey;
    final letter = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Container(
      width: radius * 2,
      height: radius * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accent.withValues(alpha: 0.18),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontSize: radius * 0.95,
          fontWeight: FontWeight.w800,
          color: AppTheme.accent,
        ),
      ),
    );
  }
}
