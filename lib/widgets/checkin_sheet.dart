import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/strings.dart';
import '../core/models/emotion.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// Callback that publishes a check-in through the core service.
typedef CheckinPublish = Future<void> Function(
  Emotion emotion,
  int intensity,
  String note,
  LocationPrecision precision,
);

/// Result of a successful check-in: what the user sent. The host screen
/// uses it to open the after-send afterglow (R10/R11).
class CheckinResult {
  const CheckinResult({required this.emotion, required this.intensity});

  /// The emotion the user picked.
  final Emotion emotion;

  /// The intensity 1–5 the user picked.
  final int intensity;
}

/// Opens the check-in bottom sheet.
/// Returns the published check-in, or null when the sheet was dismissed.
Future<CheckinResult?> showCheckinSheet(
  BuildContext context, {
  required Strings s,
  required CheckinPublish publish,
  LocationPrecision initialPrecision = LocationPrecision.off,
}) {
  return showModalBottomSheet<CheckinResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => CheckinSheet(
      s: s,
      publish: publish,
      initialPrecision: initialPrecision,
    ),
  );
}

/// Bottom sheet: "How do you feel?" — 8 emotion buttons, intensity 1–5,
/// note (max 140 chars), coarse location picker and the send button.
class CheckinSheet extends StatefulWidget {
  const CheckinSheet({
    super.key,
    required this.s,
    required this.publish,
    this.initialPrecision = LocationPrecision.off,
  });

  final Strings s;
  final CheckinPublish publish;
  final LocationPrecision initialPrecision;

  @override
  State<CheckinSheet> createState() => _CheckinSheetState();
}

class _CheckinSheetState extends State<CheckinSheet>
    with SingleTickerProviderStateMixin {
  Emotion? _emotion;
  int _intensity = 3;
  final TextEditingController _note = TextEditingController();
  late LocationPrecision _precision = widget.initialPrecision;
  bool _sending = false;
  bool _sent = false;

  /// Drives the success overlay (scrim fade + check mark pop).
  late final AnimationController _confirm = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _confirmScale = CurvedAnimation(
    parent: _confirm,
    curve: Curves.easeOutBack,
  );

  static const Color _sheetTop = Color(0xFF141A31);
  static const Color _sheetBottom = Color(0xFF0E1430);

  bool get _canSend => _emotion != null && !_sending && !_sent;

  @override
  void dispose() {
    _confirm.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final emotion = _emotion;
    if (emotion == null || _sending || _sent) return;
    setState(() => _sending = true);
    try {
      await widget.publish(emotion, _intensity, _note.text.trim(), _precision);
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _confirm.forward(from: 0);
      setState(() {
        _sending = false;
        _sent = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(
          CheckinResult(emotion: emotion, intensity: _intensity),
        );
      }
    } catch (_) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.s.tr('checkin.failed')),
          backgroundColor: const Color(0xFF7F1D1D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_sheetTop, _sheetBottom],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Stack(
          children: [
            SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.tr('checkin.title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _emotionGrid(s),
                    const SizedBox(height: 22),
                    _intensityRow(s),
                    const SizedBox(height: 12),
                    _noteField(s),
                    const SizedBox(height: 16),
                    _locationPicker(s),
                    const SizedBox(height: 22),
                    _sendButton(s),
                  ],
                ),
              ),
            ),
            if (_sent) Positioned.fill(child: _confirmationOverlay(s)),
          ],
        ),
      ),
    );
  }

  /// Success overlay: a scrim with a popping check mark in the emotion colour.
  Widget _confirmationOverlay(Strings s) {
    final color = _emotion?.color ?? AppTheme.accent;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          color: _sheetBottom.withValues(alpha: 0.93),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _confirm,
            child: ScaleTransition(
              scale: _confirmScale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.18),
                      boxShadow: AppTheme.glow(
                        color,
                        opacity: 0.45,
                        blur: 36,
                        spread: 2,
                      ),
                    ),
                    child: Icon(Icons.check_rounded, size: 52, color: color),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    s.tr('checkin.sent'),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emotionGrid(Strings s) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.88,
      children: [
        for (final emotion in Emotion.values) _emotionTile(emotion, s),
      ],
    );
  }

  Widget _emotionTile(Emotion emotion, Strings s) {
    final selected = _emotion == emotion;
    return GestureDetector(
      key: Key('emotion_${emotion.slug}'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _emotion = emotion);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: emotion.color.withValues(alpha: selected ? 0.30 : 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: emotion.color.withValues(alpha: selected ? 0.95 : 0.35),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: emotion.color.withValues(alpha: 0.40),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emotion.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                emotion.label(s.language),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: selected ? 1 : 0.72),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intensityRow(Strings s) {
    final color = _emotion?.color ?? AppTheme.accent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              s.tr('checkin.intensity'),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_intensity/5',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: _intensity.toDouble(),
          min: 1,
          max: 5,
          divisions: 4,
          label: '$_intensity',
          activeColor: color,
          inactiveColor: Colors.white.withValues(alpha: 0.14),
          onChanged: (value) => setState(() => _intensity = value.round()),
        ),
      ],
    );
  }

  Widget _noteField(Strings s) {
    return TextField(
      key: const Key('checkin_note'),
      controller: _note,
      maxLength: 140,
      maxLines: 2,
      minLines: 1,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: s.tr('checkin.noteHint'),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        counterStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.30),
          fontSize: 11,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppTheme.accent.withValues(alpha: 0.7)),
        ),
      ),
    );
  }

  Widget _locationPicker(Strings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.tr('checkin.location'),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<LocationPrecision>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: LocationPrecision.off,
              label: Text(s.tr('checkin.locOff')),
              icon: const Icon(Icons.location_off_outlined, size: 15),
            ),
            ButtonSegment(
              value: LocationPrecision.city,
              label: Text(s.tr('checkin.locCity')),
              icon: const Icon(Icons.location_city, size: 15),
            ),
            ButtonSegment(
              value: LocationPrecision.area,
              label: Text(s.tr('checkin.locArea')),
              icon: const Icon(Icons.blur_circular, size: 15),
            ),
          ],
          selected: {_precision},
          onSelectionChanged: (selection) =>
              setState(() => _precision = selection.first),
          style: ButtonStyle(
            textStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.tr('checkin.locHint'),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }

  Widget _sendButton(Strings s) {
    final color = _emotion?.color ?? AppTheme.accent;
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    return SizedBox(
      height: 52,
      child: FilledButton(
        key: const Key('checkin_send'),
        onPressed: _canSend ? _send : null,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: foreground,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _sent
              ? Row(
                  key: const ValueKey('sent'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, size: 20),
                    const SizedBox(width: 8),
                    Text(s.tr('checkin.sent')),
                  ],
                )
              : _sending
              ? Row(
                  key: const ValueKey('sending'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(s.tr('checkin.sending')),
                  ],
                )
              : Text(
                  s.tr('checkin.send'),
                  key: const ValueKey('send'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}
