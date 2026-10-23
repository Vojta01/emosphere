// R9 — the map "time machine" bar.
//
// A slim control strip under the window switcher: play/pause, the timeline
// slider (left edge = start of the selected window, right edge = now), the
// instant label and the replay-window chips (1 h / 6 h / 24 h). The screen
// owns the state; this widget is a pure view so tests can drive it directly.

import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../theme/app_theme.dart';

/// Replay window lengths offered by the time machine.
///
/// R9 decision: 1 h / 6 h / 24 h, 6 h defaulted on the screen.
const List<Duration> machineWindows = <Duration>[
  Duration(hours: 1),
  Duration(hours: 6),
  Duration(hours: 24),
];

/// Formats the scrubbed instant: `pá 12. 10. · 14:30` (cs) /
/// `Fri 12 Oct · 14:30` (en). Time is shown in the device zone.
String formatMachineLabel(DateTime instant, String lang) {
  final local = instant.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (lang == 'en') {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = days[local.weekday - 1];
    final month = months[local.month - 1];
    return '$day ${local.day} $month · $hh:$mm';
  }
  const days = ['po', 'út', 'st', 'čt', 'pá', 'so', 'ne'];
  final day = days[local.weekday - 1];
  return '$day ${local.day}. ${local.month}. · $hh:$mm';
}

/// The time-machine control bar (R9).
class TimelineBar extends StatelessWidget {
  const TimelineBar({
    super.key,
    required this.language,
    required this.live,
    required this.fraction,
    required this.playing,
    required this.instant,
    required this.machineWindow,
    required this.onPlayPause,
    required this.onScrub,
    required this.onLive,
    required this.onMachineWindow,
  });

  /// Active language code (`cs` / `en`).
  final String language;

  /// `true` in live mode (right edge — the map shows the whole window).
  final bool live;

  /// Slider position 0..1 (1 = now).
  final double fraction;

  /// `true` while the replay animation runs — the button shows ⏸.
  final bool playing;

  /// Instant the slider points at; `null` in live mode.
  final DateTime? instant;

  /// Selected replay window length.
  final Duration machineWindow;

  final VoidCallback onPlayPause;
  final ValueChanged<double> onScrub;
  final VoidCallback onLive;
  final ValueChanged<Duration> onMachineWindow;

  @override
  Widget build(BuildContext context) {
    final s = Strings(language);
    final at = instant;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _playButton(s),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 3,
                  activeTrackColor: AppTheme.accent,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
                  thumbColor: AppTheme.accent,
                  overlayColor: AppTheme.accent.withValues(alpha: 0.16),
                  thumbShape:
                      const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                  overlayShape:
                      const RoundSliderOverlayShape(overlayRadius: 13),
                ),
                child: Slider(
                  key: const Key('map_timeline'),
                  value: fraction.clamp(0.0, 1.0),
                  onChanged: onScrub,
                ),
              ),
            ),
            if (!live)
              TextButton(
                key: const Key('map_live_now'),
                onPressed: onLive,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 30),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: AppTheme.accent,
                  textStyle: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(s.tr('map.now')),
              ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, right: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  live || at == null
                      ? s.tr('map.live')
                      : formatMachineLabel(at, language),
                  key: const Key('map_timeline_label'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: live
                        ? Colors.white.withValues(alpha: 0.55)
                        : AppTheme.accent,
                  ),
                ),
              ),
              Text(
                s.tr('map.replayWindow'),
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 6),
              for (final window in machineWindows) ...[
                _chip(window),
                if (window != machineWindows.last) const SizedBox(width: 5),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _playButton(Strings s) {
    return Tooltip(
      message: s.tr(playing ? 'map.pause' : 'map.play'),
      child: Material(
        color: AppTheme.accent.withValues(alpha: playing ? 0.28 : 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          key: const Key('map_play'),
          customBorder: const CircleBorder(),
          onTap: onPlayPause,
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: Icon(
              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 19,
              color: AppTheme.accent,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(Duration window) {
    final selected = window == machineWindow;
    return ChoiceChip(
      key: Key('machine_${window.inHours}h'),
      label: Text('${window.inHours}h'),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onMachineWindow(window),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      labelStyle: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 5),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      selectedColor: AppTheme.accent.withValues(alpha: 0.30),
      backgroundColor: Colors.white.withValues(alpha: 0.06),
      side: BorderSide(
        color: selected
            ? AppTheme.accent.withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.12),
      ),
      shape: const StadiumBorder(),
    );
  }
}
