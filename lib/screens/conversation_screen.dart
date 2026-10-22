// One conversation (R5) — an encrypted NIP-04 chat with a single author.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/strings.dart';
import '../core/models/dm.dart';
import '../core/nostr/nip19.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/user_avatar.dart';

/// Full-screen chat with [pubkey] (NIP-04 direct messages).
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.app,
    required this.pubkey,
  });

  final AppState app;

  /// Hex pubkey of the other party.
  final String pubkey;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _input = TextEditingController();
  bool _sending = false;

  String get _key => widget.pubkey.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    // Reading the marker happens post-frame (see [build]) — notifying the
    // app synchronously here would mark listeners dirty during the build
    // phase that mounts this route.
    unawaited(widget.app.refreshDms());
    unawaited(widget.app.ensureProfile(_key));
    widget.app.startDmLiveUpdates();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.app.sendDm(recipientPubkey: _key, text: text);
      _input.clear();
      HapticFeedback.lightImpact();
    } on Object {
      if (mounted) {
        final s = Strings(widget.app.language);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.tr('messages.sendFailed')),
            duration: const Duration(seconds: 2),
            backgroundColor: const Color(0xFF7F1D1D),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final s = Strings(widget.app.language);
        final profile = widget.app.profileOf(_key);
        final name = profile?.bestName ?? shortenKey(_key);
        final messages = widget.app.conversationWith(_key);
        // While the chat is open, new incoming messages count as read.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.app.markConversationRead(_key);
          }
        });
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            titleSpacing: 0,
            title: Row(
              children: [
                UserAvatar(profile: profile, pubkey: _key, radius: 15),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_outline,
                                  size: 36,
                                  color: Colors.white.withValues(alpha: 0.25),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  s.tr('messages.emptyHint'),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[messages.length - 1 - index];
                            return _bubble(
                              s,
                              message,
                              widget.app.pubkeyHex?.toLowerCase() ?? '',
                            );
                          },
                        ),
                ),
                _composer(s),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bubble(Strings s, DmMessage message, String me) {
    final isMine = message.isMine(me);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMine
              ? AppTheme.accent.withValues(alpha: 0.85)
              : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          border: isMine
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              s.timeAgo(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer(Strings s) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('dm_input'),
                controller: _input,
                minLines: 1,
                maxLines: 4,
                maxLength: 500,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: s.tr('messages.inputHint'),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(width: 8),
            _sending
                ? const SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton.filled(
                    key: const Key('dm_send'),
                    onPressed: _send,
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
          ],
        ),
      ),
    );
  }
}
