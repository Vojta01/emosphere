// Author sheet (R4) — profile, npub, the tapped check-in and the social
// actions: friend toggle, DM and "show on map".
//
// Used from the feed (world tiles and friend chips) and anywhere an author
// needs actions. The sheet is self-contained: it adds/removes the friend
// itself and pushes the conversation screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/geo/geohash.dart';
import '../core/i18n/strings.dart';
import '../core/models/checkin.dart';
import '../core/nostr/nip19.dart';
import '../core/social/friends.dart';
import '../core/state/app_state.dart';
import '../screens/conversation_screen.dart';
import '../theme/app_theme.dart';
import 'user_avatar.dart';

/// Opens the author sheet for [pubkey]; [checkin] is the tapped card.
Future<void> showUserSheet(
  BuildContext context, {
  required AppState app,
  required String pubkey,
  CheckinEvent? checkin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (sheetContext) =>
        UserSheet(app: app, pubkey: pubkey, checkin: checkin),
  );
}

/// Bottom sheet with one author's profile, npub and social actions.
class UserSheet extends StatefulWidget {
  const UserSheet({
    super.key,
    required this.app,
    required this.pubkey,
    this.checkin,
  });

  final AppState app;

  /// Hex pubkey of the author.
  final String pubkey;

  /// The check-in the sheet was opened from (optional).
  final CheckinEvent? checkin;

  @override
  State<UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<UserSheet> {
  String get _key => widget.pubkey.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    unawaited(widget.app.ensureProfile(_key));
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  void _snack(String message, {Color? background}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: background,
      ),
    );
  }

  Future<void> _copyNpub(String npub) async {
    await Clipboard.setData(ClipboardData(text: npub));
    if (mounted) {
      _snack(Strings(widget.app.language).tr('common.npubCopied'));
    }
  }

  void _addFriend() {
    final s = Strings(widget.app.language);
    switch (widget.app.addFriend(_key)) {
      case AddFriendOutcome.added:
        _snack(s.tr('friendAdded'), background: const Color(0xFF14532D));
      case AddFriendOutcome.duplicate:
        _snack(s.tr('friends.duplicate'));
      case AddFriendOutcome.invalid:
        _snack(s.tr('invalidNpub'), background: const Color(0xFF7F1D1D));
    }
  }

  Future<void> _removeFriend() async {
    final s = Strings(widget.app.language);
    final name = widget.app.profileOf(_key)?.bestName ?? shortenKey(_key);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.tr('friends.removeConfirm')),
        content: Text('$name\n\n${s.tr('friends.removeBody')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('friends_remove_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    final removed = widget.app.removeFriend(_key);
    if (mounted) {
      Navigator.of(context).pop();
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(removed ? s.tr('friendRemoved') : s.tr('errorGeneric')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openConversation() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ConversationScreen(app: widget.app, pubkey: _key),
      ),
    );
  }

  void _showOnMap() {
    final geohash = widget.checkin?.geohash;
    if (geohash == null || geohash.isEmpty) {
      return;
    }
    try {
      final point = Geohash.decode(geohash);
      Navigator.of(context).pop();
      widget.app.requestMapFocus(point);
    } on FormatException {
      // A malformed geohash — nothing to show.
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final s = Strings(app.language);
        final profile = app.profileOf(_key);
        final name = profile?.bestName ?? shortenKey(_key);
        final npub = encodeNpub(_key);
        final isFriend = app.friends.contains(_key);
        final checkin = widget.checkin;
        final place = _placeLabel(checkin);
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            decoration: AppTheme.glassDecoration(
              radius: 26,
              tint: AppTheme.surfaceHigh,
              opacity: 0.98,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    UserAvatar(profile: profile, pubkey: _key, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            profile?.nip05 ?? shortenKey(_key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (checkin != null) ...[
                  const SizedBox(height: 14),
                  _checkinBlock(s, checkin, place),
                ],
                const SizedBox(height: 14),
                SelectableText(
                  npub,
                  key: const Key('friends_npub_value'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('friends_copy_npub'),
                        onPressed: () => _copyNpub(npub),
                        icon: const Icon(Icons.copy, size: 16),
                        label: Text(s.copy),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: isFriend
                          ? OutlinedButton.icon(
                              key: const Key('friends_remove'),
                              onPressed: _removeFriend,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: BorderSide(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.5),
                                ),
                              ),
                              icon: const Icon(
                                Icons.person_remove_alt_1,
                                size: 16,
                              ),
                              label: Text(
                                s.tr('user.removeFriend'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : FilledButton.icon(
                              key: const Key('user_add_friend'),
                              onPressed: _addFriend,
                              icon: const Icon(
                                Icons.person_add_alt_1,
                                size: 16,
                              ),
                              label: Text(
                                s.tr('user.addFriend'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton.tonalIcon(
                  key: const Key('user_message'),
                  onPressed: _openConversation,
                  icon: const Icon(Icons.forum_outlined, size: 17),
                  label: Text(s.tr('messages.write')),
                ),
                if (place != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const Key('user_show_on_map'),
                    onPressed: _showOnMap,
                    icon: const Icon(Icons.map_outlined, size: 17),
                    label: Text(s.tr('user.showOnMap')),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _checkinBlock(Strings s, CheckinEvent checkin, String? place) {
    final emotion = checkin.emotion;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: AppTheme.glassDecoration(
        radius: 16,
        tint: emotion.color,
        opacity: 0.14,
        glowColor: emotion.color,
        glowBlur: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: emotion.color,
                  boxShadow: AppTheme.glow(
                    emotion.color,
                    opacity: 0.6,
                    blur: 10,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${emotion.label(s.language)} · ${checkin.intensity}/5',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                s.timeAgo(checkin.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
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
          if (place != null) ...[
            const SizedBox(height: 6),
            Text(
              place,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Coarse place of the tapped check-in (cell centre, never the exact spot).
  String? _placeLabel(CheckinEvent? checkin) {
    final geohash = checkin?.geohash;
    if (geohash == null || geohash.isEmpty) {
      return null;
    }
    try {
      final point = Geohash.decode(geohash);
      final lat = point.latitude.toStringAsFixed(2);
      final lon = point.longitude.toStringAsFixed(2);
      return '≈ $lat, $lon';
    } on FormatException {
      return null;
    }
  }
}
