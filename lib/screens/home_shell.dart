import 'package:flutter/material.dart';

import '../core/i18n/strings.dart';
import '../core/quotes/quotes.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/afterglow_overlay.dart';
import '../widgets/checkin_sheet.dart';
import 'feed_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

/// Main shell: bottom navigation (Map, Feed, History, Settings)
/// and the floating "How do you feel?" button.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.app});

  final AppState app;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    widget.app.addListener(_onAppChanged);
  }

  @override
  void dispose() {
    widget.app.removeListener(_onAppChanged);
    super.dispose();
  }

  /// Switches to the map tab when a "show on map" request arrives (R4).
  void _onAppChanged() {
    if (widget.app.mapFocusRequest != null && _index != 0) {
      setState(() => _index = 0);
    }
  }

  Future<void> _openCheckin() async {
    final s = Strings(widget.app.language);
    final result = await showCheckinSheet(
      context,
      s: s,
      initialPrecision: widget.app.locationPrecision,
      publish: (emotion, intensity, note, precision) =>
          widget.app.publishCheckin(
            emotion: emotion,
            intensity: intensity,
            note: note,
            precision: precision,
          ),
    );
    if (result == null || !mounted) {
      return;
    }
    // R10/R11: the sheet closed, so play the afterglow with a quote. When
    // the quote asset failed to load, keep the plain confirmation instead.
    final quote = QuotesLibrary.instance?.randomFor(result.emotion);
    if (quote == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.tr('checkin.sent')),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF14532D),
        ),
      );
      return;
    }
    await showAfterglow(
      context,
      s: s,
      emotion: result.emotion,
      intensity: result.intensity,
      quote: quote,
      haptics: widget.app.afterglowHaptics,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on every app change: the tab labels and the FAB follow the
    // language switch, and History/Settings get fresh `Strings` and check-ins.
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final s = Strings(widget.app.language);
        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: IndexedStack(
              index: _index,
              children: [
                MapScreen(app: widget.app),
                FeedScreen(app: widget.app),
                HistoryScreen(s: s, checkins: widget.app.myCheckins),
                SettingsScreen(app: widget.app, s: s),
              ],
            ),
          ),
          floatingActionButton: _fab(s),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: _navBar(s),
        );
      },
    );
  }

  Widget _fab(Strings s) {
    return FloatingActionButton.extended(
      onPressed: _openCheckin,
      backgroundColor: AppTheme.accent,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      icon: const Icon(Icons.mood),
      label: Text(
        s.tr('home.fab'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _navBar(Strings s) {
    final entries = <(IconData, String)>[
      (Icons.public, s.tr('nav.map')),
      (Icons.dynamic_feed, s.tr('nav.feed')),
      (Icons.history, s.tr('nav.history')),
      (Icons.settings_outlined, s.tr('nav.settings')),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF11162C).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < entries.length; i++)
              Expanded(child: _navItem(i, entries[i].$1, entries[i].$2)),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _index == index;
    final color = selected
        ? AppTheme.accent
        : Colors.white.withValues(alpha: 0.45);
    return GestureDetector(
      key: Key('nav_$index'),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
