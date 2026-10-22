// Messages screen (R5) — the list of my NIP-04 conversations, newest first.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../core/models/dm.dart';
import '../core/nostr/nip19.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';
import 'conversation_screen.dart';

/// The list of my conversations (NIP-04 direct messages).
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.app});

  final AppState app;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.app.refreshDms());
    widget.app.startDmLiveUpdates();
  }

  void _openConversation(DmConversation conversation) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ConversationScreen(app: widget.app, pubkey: conversation.pubkey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = Strings(widget.app.language);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          s.tr('messages'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: ListenableBuilder(
          listenable: widget.app,
          builder: (context, _) {
            final conversations = widget.app.dmConversations;
            if (conversations.isEmpty) {
              return _empty(s);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              itemCount: conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _tile(s, conversations[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _empty(Strings s) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 44,
              color: Colors.white.withValues(alpha: 0.25),
            ),
            const SizedBox(height: 14),
            Text(
              s.tr('messages.empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.tr('messages.emptyHint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(Strings s, DmConversation conversation) {
    final profile = widget.app.profileOf(conversation.pubkey);
    final name = profile?.bestName ?? shortenKey(conversation.pubkey);
    final last = conversation.last;
    final me = widget.app.pubkeyHex?.toLowerCase() ?? '';
    final preview = last.isMine(me)
        ? '${s.tr('messages.you')}: ${last.text}'
        : last.text;
    return GlassCard(
      radius: 18,
      onTap: () => _openConversation(conversation),
      child: Row(
        children: [
          UserAvatar(profile: profile, pubkey: conversation.pubkey, radius: 20),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                s.timeAgo(last.createdAt),
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              if (conversation.unread > 0) ...[
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${conversation.unread}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
