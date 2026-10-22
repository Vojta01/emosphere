// NIP-04 direct message model (kind 4) plus the conversation grouping used
// by the messages screens.

/// One decrypted direct message.
class DmMessage {
  const DmMessage({
    required this.id,
    required this.senderPubkey,
    required this.recipientPubkey,
    required this.text,
    required this.createdAt,
  });

  /// Event id (64 hex chars).
  final String id;

  /// Author public key (hex, lowercase).
  final String senderPubkey;

  /// Recipient public key (hex, lowercase) — the `p` tag of the event.
  final String recipientPubkey;

  /// Decrypted plaintext.
  final String text;

  /// Creation time (UTC).
  final DateTime createdAt;

  /// Whether [myPubkey] wrote this message.
  bool isMine(String myPubkey) => senderPubkey == myPubkey;

  /// The other party of the conversation as seen by [myPubkey].
  String counterparty(String myPubkey) =>
      senderPubkey == myPubkey ? recipientPubkey : senderPubkey;

  /// Plain JSON map (used for the local DM cache).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sender': senderPubkey,
      'recipient': recipientPubkey,
      'text': text,
      'created_at': createdAt.toUtc().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Restores a message from [toJson]. Returns `null` for malformed maps.
  static DmMessage? fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final sender = json['sender'] as String?;
    final recipient = json['recipient'] as String?;
    final text = json['text'] as String?;
    if (id == null || sender == null || recipient == null || text == null) {
      return null;
    }
    final seconds = (json['created_at'] as num?)?.toInt() ?? 0;
    return DmMessage(
      id: id,
      senderPubkey: sender,
      recipientPubkey: recipient,
      text: text,
      createdAt: DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
  }

  @override
  String toString() =>
      'DmMessage(${text.length} chars, $senderPubkey -> $recipientPubkey, '
      '$createdAt)';
}

/// One conversation: the counterparty plus the messages, oldest first.
class DmConversation {
  const DmConversation({
    required this.pubkey,
    required this.messages,
    required this.unread,
  });

  /// Hex pubkey of the other party.
  final String pubkey;

  /// Messages with that party, oldest first (never empty).
  final List<DmMessage> messages;

  /// Incoming messages newer than the local read marker.
  final int unread;

  /// The newest message.
  DmMessage get last => messages.last;
}
