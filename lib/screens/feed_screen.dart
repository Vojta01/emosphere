// Feed screen — "My close ones" and "Right now in the world" (card 3).
//
// One scroll view with two sections:
//   * My close ones — the friend chips (kind 0 name + avatar), the add / remove
//     / share-npub actions and the latest check-in of every friend.
//   * Right now in the world — the newest 50 check-ins of the world pool,
//     tinted by emotion with the relative time, the note and the intensity.
//
// Everything reads from and writes to [AppState], so a friend added here shows
// up on the map (and vice versa) without any extra plumbing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/feed/feed_logic.dart';
import '../core/i18n/strings.dart';
import '../core/models/checkin.dart';
import '../core/models/profile.dart';
import '../core/nostr/nip19.dart';
import '../core/social/friends.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/key_qr_dialog.dart';
import '../widgets/user_sheet.dart';
import 'messages_screen.dart';

/// The world feed with the friends section on top.
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.app});

  /// Application state (world and friend check-ins live here).
  final AppState app;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _loadingFriends = false;

  Strings get _s => Strings(widget.app.language);

  void _snack(String message, {Color? background}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: background,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------

  Future<void> _refresh() async {
    await widget.app.refresh();
  }

  /// Reloads the friend profiles (kind 0) and their newest check-ins.
  Future<void> _loadFriends() async {
    if (_loadingFriends) {
      return;
    }
    setState(() => _loadingFriends = true);
    await widget.app.refreshProfiles();
    await widget.app.refreshFriendCheckins();
    if (mounted) {
      setState(() => _loadingFriends = false);
    }
  }

  Future<void> _addFriend() async {
    final outcome = await showDialog<AddFriendOutcome>(
      context: context,
      builder: (context) => _AddFriendDialog(s: _s, app: widget.app),
    );
    if (!mounted || outcome == null) {
      return;
    }
    final s = _s;
    switch (outcome) {
      case AddFriendOutcome.added:
        _snack(s.tr('friendAdded'), background: const Color(0xFF14532D));
      case AddFriendOutcome.duplicate:
        _snack(s.tr('friends.duplicate'));
      case AddFriendOutcome.invalid:
        _snack(s.tr('invalidNpub'), background: const Color(0xFF7F1D1D));
    }
  }

  Future<void> _shareNpub() async {
    final s = _s;
    final npub = widget.app.npub;
    if (npub == null || npub.isEmpty) {
      _snack(s.tr('noIdentity'));
      return;
    }
    HapticFeedback.lightImpact();
    await showKeyQrDialog(
      context,
      s: s,
      title: s.tr('myNpub'),
      value: npub,
      hint: s.tr('set.npubQrHint'),
      copyMessage: s.tr('common.npubCopied'),
      keyPrefix: 'friends',
      masked: false,
    );
  }

  /// Asks for confirmation and removes [pubkey] from the friend list.
  Future<void> _removeFriend(String pubkey) async {
    final s = _s;
    final name = widget.app.profileOf(pubkey)?.bestName ?? shortenKey(pubkey);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.tr('friends.removeConfirm')),
        content: Text('$name\n\n${s.tr('friends.removeBody')}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('friends_remove_confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.remove),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final removed = widget.app.removeFriend(pubkey);
    if (mounted) {
      _snack(removed ? s.tr('friendRemoved') : s.tr('errorGeneric'));
    }
  }

  /// Bottom sheet with one author: profile, npub and the social actions (R4).
  Future<void> _openUser(String pubkey, {CheckinEvent? checkin}) async {
    await showUserSheet(
      context,
      app: widget.app,
      pubkey: pubkey,
      checkin: checkin,
    );
  }

  /// Opens the messages screen (R5).
  void _openMessages() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MessagesScreen(app: widget.app),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.app,
        builder: (context, _) {
          final s = _s;
          final app = widget.app;
          final pool = checkinPool(app.worldCheckins, app.friendCheckins);
          final closeOnes = friendsFeed(pool, app.friends);
          final world = worldFeed(
            pool,
            excludePubkey: app.pubkeyHex,
            limit: worldFeedLimit,
          );
          return RefreshIndicator(
            color: AppTheme.accent,
            backgroundColor: AppTheme.surfaceHigh,
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
              children: [
                _header(s),
                const SizedBox(height: 18),
                _friendsSection(s, app, closeOnes),
                const SizedBox(height: 24),
                _worldSection(s, world),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(Strings s) {
    final app = widget.app;
    return Row(
      children: [
        Expanded(
          child: Text(
            s.tr('feed'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          key: const Key('feed_messages'),
          tooltip: s.tr('messages'),
          visualDensity: VisualDensity.compact,
          onPressed: _openMessages,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 19,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              if (app.unreadDmCount > 0)
                Positioned(
                  right: -5,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${app.unreadDmCount}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (app.isSyncing)
          const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Tooltip(
            message: s.tr('relays'),
            child: Icon(
              app.isConnected
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              size: 17,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }

  Widget _friendsSection(
    Strings s,
    AppState app,
    List<CheckinEvent> closeOnes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.favorite, size: 17, color: AppTheme.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.tr('friendsSection'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            if (_loadingFriends)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                key: const Key('feed_reload_friends'),
                tooltip: s.tr('friends.loadProfiles'),
                visualDensity: VisualDensity.compact,
                color: AppTheme.accent,
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: _loadFriends,
              ),
            IconButton(
              key: const Key('feed_share_npub'),
              tooltip: s.tr('set.shareNpub'),
              visualDensity: VisualDensity.compact,
              color: AppTheme.accent,
              icon: const Icon(Icons.qr_code_2, size: 19),
              onPressed: _shareNpub,
            ),
            IconButton(
              key: const Key('feed_add_friend'),
              tooltip: s.tr('addFriend'),
              visualDensity: VisualDensity.compact,
              color: AppTheme.accent,
              icon: const Icon(Icons.person_add_alt_1, size: 19),
              onPressed: _addFriend,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (app.friends.isEmpty)
          GlassCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.tr('friendsEmpty'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.tr('friendsEmptyFeed'),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const Key('feed_add_friend_cta'),
                  onPressed: _addFriend,
                  icon: const Icon(Icons.person_add_alt_1, size: 17),
                  label: Text(s.tr('friends.addAction')),
                ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pubkey in app.friends)
                _friendChip(s, app, pubkey, closeOnes),
            ],
          ),
          const SizedBox(height: 14),
          if (closeOnes.isEmpty)
            Text(
              s.tr('friendsEmptyFeed'),
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            )
          else
            for (final checkin in closeOnes)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FriendTile(
                  checkin: checkin,
                  profile: app.profileOf(checkin.pubkey),
                  s: s,
                ),
              ),
        ],
      ],
    );
  }

  Widget _friendChip(
    Strings s,
    AppState app,
    String pubkey,
    List<CheckinEvent> closeOnes,
  ) {
    final profile = app.profileOf(pubkey);
    final latest = closeOnes.where(
      (checkin) => checkin.pubkey.toLowerCase() == pubkey.toLowerCase(),
    );
    return InputChip(
      key: Key('friend_chip_${shortenKey(pubkey, head: 6, tail: 0)}'),
      avatar: _Avatar(profile: profile, pubkey: pubkey, radius: 13),
      label: Text(
        profile?.bestName ?? shortenKey(pubkey),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 2),
      backgroundColor: AppTheme.surfaceHigh,
      side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.35)),
      shape: const StadiumBorder(),
      deleteIcon: const Icon(Icons.close, size: 14),
      deleteIconColor: Colors.white.withValues(alpha: 0.5),
      deleteButtonTooltipMessage: s.tr('friends.removeConfirm'),
      onDeleted: () => _removeFriend(pubkey),
      onPressed: () => _openUser(pubkey),
      tooltip: latest.isEmpty
          ? s.tr('friends.noCheckins')
          : s.timeAgo(latest.first.createdAt),
    );
  }

  Widget _worldSection(Strings s, List<CheckinEvent> world) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                s.tr('worldSection'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Text(
              '${world.length} ${s.tr('feed.posts')}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (world.isEmpty)
          GlassCard(
            radius: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🌍', style: TextStyle(fontSize: 30)),
                const SizedBox(height: 10),
                Text(
                  s.tr('feedEmpty'),
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          )
        else
          for (final checkin in world)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _WorldTile(
              checkin: checkin,
              s: s,
              onTap: () => _openUser(checkin.pubkey, checkin: checkin),
            ),
            ),
      ],
    );
  }
}

/// Emotion-tinted surface used for the feed cards.
///
/// Cheaper than [GlassCard]: no backdrop blur, which matters with a 50 item
/// world feed on mid-range phones.
class _Surface extends StatelessWidget {
  const _Surface({required this.child, required this.color});

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: AppTheme.glassDecoration(
        radius: 18,
        tint: color,
        opacity: 0.13,
        glowColor: color,
        glowBlur: 16,
      ),
      child: child,
    );
  }
}

/// Round avatar of a friend: the kind 0 `picture`, otherwise a coloured initial.
class _Avatar extends StatelessWidget {
  const _Avatar({
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

/// Latest check-in of one friend: kind 0 name, accent ring, emotion colour.
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.checkin,
    required this.profile,
    required this.s,
  });

  final CheckinEvent checkin;
  final NostrProfile? profile;
  final Strings s;

  @override
  Widget build(BuildContext context) {
    final emotion = checkin.emotion;
    final name = profile?.bestName ?? shortenKey(checkin.pubkey);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: AppTheme.glassDecoration(
        radius: 18,
        tint: emotion.color,
        opacity: 0.13,
        glowColor: emotion.color,
        glowBlur: 16,
      ),
      foregroundDecoration: BoxDecoration(
        // The accent ring marks a friend, same as on the map heat layer.
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.55),
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(profile: profile, pubkey: checkin.pubkey, radius: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${emotion.emoji} ${emotion.label(s.language)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: emotion.color,
                      ),
                    ),
                  ],
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
          const SizedBox(height: 8),
          _IntensityRow(checkin: checkin),
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
    );
  }
}

/// One card of "right now in the world": emotion colour, time, note, intensity.
class _WorldTile extends StatelessWidget {
  const _WorldTile({required this.checkin, required this.s, this.onTap});

  final CheckinEvent checkin;
  final Strings s;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final emotion = checkin.emotion;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: _Surface(
      color: emotion.color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emotion.color.withValues(alpha: 0.16),
              border: Border.all(color: emotion.color.withValues(alpha: 0.5)),
            ),
            child: Text(emotion.emoji, style: const TextStyle(fontSize: 19)),
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
                const SizedBox(height: 5),
                _IntensityRow(checkin: checkin),
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
      ),
    );
  }
}

/// Five dots, [CheckinEvent.intensity] of them filled in the emotion colour.
class _IntensityRow extends StatelessWidget {
  const _IntensityRow({required this.checkin});

  final CheckinEvent checkin;

  @override
  Widget build(BuildContext context) {
    final emotion = checkin.emotion;
    return Row(
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
          const SizedBox(width: 6),
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
    );
  }
}

/// Dialog that validates an `npub` / hex key and adds it to the friend list.
class _AddFriendDialog extends StatefulWidget {
  const _AddFriendDialog({required this.s, required this.app});

  final Strings s;
  final AppState app;

  @override
  State<_AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<_AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  bool _valid = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final text = value.trim();
    setState(() {
      if (text.isEmpty) {
        _valid = false;
        _error = null;
        return;
      }
      _valid = parseFriendInput(text) != null;
      _error = _valid ? null : widget.s.tr('invalidNpub');
    });
  }

  void _submit() {
    Navigator.of(context).pop(widget.app.addFriend(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AlertDialog(
      title: Text(
        s.tr('addFriend'),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('friends_npub_field'),
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            onSubmitted: (_) {
              if (_valid) {
                _submit();
              }
            },
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: InputDecoration(
              hintText: s.tr('friends.addHint'),
              prefixIcon: const Icon(Icons.person_add_alt_1, size: 18),
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _valid ? s.tr('friends.valid') : s.tr('checkin.locHint'),
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: _valid
                  ? const Color(0xFF4ADE80)
                  : Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          key: const Key('friends_add_confirm'),
          onPressed: _valid ? _submit : null,
          child: Text(s.tr('friends.addAction')),
        ),
      ],
    );
  }
}
