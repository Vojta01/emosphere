// Modal that shows a Nostr key as text, with a copy button and a QR code.
//
// Extracted from the settings screen (card 2) so the friends section (card 3)
// can share an npub with exactly the same dialog. Secret keys (`nsec`) stay
// masked until the user reveals them; public keys (`npub`) are shown as-is.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/i18n/strings.dart';
import '../theme/app_theme.dart';

/// Opens [KeyQrDialog] for [value] (an `npub` or `nsec`).
///
/// [keyPrefix] namespaces the widget keys so widget tests can address two
/// dialogs of the same kind (settings vs. friends).
Future<void> showKeyQrDialog(
  BuildContext context, {
  required Strings s,
  required String title,
  required String value,
  required String hint,
  required String copyMessage,
  String? warning,
  String keyPrefix = 'settings',
  bool masked = true,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => KeyQrDialog(
      s: s,
      title: title,
      value: value,
      hint: hint,
      copyMessage: copyMessage,
      warning: warning,
      keyPrefix: keyPrefix,
      masked: masked,
    ),
  );
}

/// Dialog with the key text, a copy action and a QR code of the key.
class KeyQrDialog extends StatefulWidget {
  const KeyQrDialog({
    super.key,
    required this.s,
    required this.title,
    required this.value,
    required this.hint,
    required this.copyMessage,
    this.warning,
    this.keyPrefix = 'settings',
    this.masked = true,
  });

  /// Localized strings of the current app language.
  final Strings s;

  /// Dialog title (already localized).
  final String title;

  /// Key shown as text and encoded into the QR code.
  final String value;

  /// Hint printed under the QR code.
  final String hint;

  /// Snack bar text after a successful copy.
  final String copyMessage;

  /// Optional warning banner (secret key).
  final String? warning;

  /// Prefix of the widget keys (`<prefix>_key_value`, `…_key_toggle`,
  /// `…_key_copy`).
  final String keyPrefix;

  /// Whether the text starts hidden behind dots (secret keys only).
  final bool masked;

  @override
  State<KeyQrDialog> createState() => _KeyQrDialogState();
}

class _KeyQrDialogState extends State<KeyQrDialog> {
  late bool _revealed = !widget.masked;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) {
      return;
    }
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.copyMessage),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final warning = widget.warning;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.key, size: 18, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (warning != null) ...[
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 17,
                      color: Color(0xFFFBBF24),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        warning,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: const Color(0xFFFBBF24)
                              .withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: SelectableText(
                _revealed ? widget.value : '•' * 20,
                key: Key('${widget.keyPrefix}_key_value'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (widget.masked)
                  Expanded(
                    child: TextButton.icon(
                      key: Key('${widget.keyPrefix}_key_toggle'),
                      onPressed: () => setState(() => _revealed = !_revealed),
                      icon: Icon(
                        _revealed ? Icons.visibility_off : Icons.visibility,
                        size: 16,
                      ),
                      label: Text(
                        widget.s.tr(
                          _revealed ? 'set.hideKey' : 'set.revealKey',
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  key: Key('${widget.keyPrefix}_key_copy'),
                  tooltip: widget.copyMessage,
                  color: AppTheme.accent,
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: _copy,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // A tight box stops the AlertDialog intrinsic measurement before
            // it reaches the QR widget's LayoutBuilder.
            Center(
              child: SizedBox(
                width: 192,
                height: 192,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: widget.value,
                    version: QrVersions.auto,
                    size: 168,
                    backgroundColor: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.s.tr('close')),
        ),
      ],
    );
  }
}
