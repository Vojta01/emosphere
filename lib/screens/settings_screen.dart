// Settings screen — relays, location precision, language, key, data.
//
// Minimal scaffold for the core (card 1); card 2 extends it (key backup with
// QR, about dialog, haptics).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/strings.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// Settings: profile key, language, location precision, relays, my data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.app, required this.s});

  /// Application state.
  final AppState app;

  /// Localized strings of the current language.
  final Strings s;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _relays = TextEditingController(
    text: widget.app.relays.join('\n'),
  );

  @override
  void dispose() {
    _relays.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _saveRelays() async {
    await widget.app.setRelays(_relays.text.split('\n'));
    if (!mounted) {
      return;
    }
    _relays.text = widget.app.relays.join('\n');
    _snack(widget.s.tr('relaysSaved'));
  }

  Future<void> _confirmDelete() async {
    final s = widget.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.tr('deleteMyData')),
        content: Text(s.tr('deleteMyDataBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.app.deleteMyCheckins();
      if (mounted) {
        _snack(s.tr('deleted'));
      }
    } on Object {
      if (mounted) {
        _snack(s.errorGeneric);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final app = widget.app;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 170),
        children: [
          Text(
            s.tr('settings'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _profileCard(s, app),
          const SizedBox(height: 12),
          _languageCard(s, app),
          const SizedBox(height: 12),
          _locationCard(s, app),
          const SizedBox(height: 12),
          _relaysCard(s),
          const SizedBox(height: 12),
          _dangerCard(s),
          const SizedBox(height: 12),
          _aboutCard(s),
        ],
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _profileCard(Strings s, AppState app) {
    final npub = app.npub;
    return _section(
      title: s.tr('profile'),
      child: Row(
        children: [
          Expanded(
            child: Text(
              npub == null || npub.isEmpty ? s.noIdentity : npub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          if (npub != null)
            IconButton(
              tooltip: s.copy,
              color: AppTheme.accent,
              icon: const Icon(Icons.copy, size: 18),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: npub));
                if (mounted) {
                  _snack(s.tr('common.npubCopied'));
                }
              },
            ),
        ],
      ),
    );
  }

  Widget _languageCard(Strings s, AppState app) {
    return _section(
      title: s.tr('language'),
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment<String>(value: 'cs', label: Text('Čeština')),
          ButtonSegment<String>(value: 'en', label: Text('English')),
        ],
        selected: <String>{app.language},
        onSelectionChanged: (selection) => app.setLanguage(selection.first),
      ),
    );
  }

  Widget _locationCard(Strings s, AppState app) {
    return _section(
      title: s.tr('locationPrecision'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<LocationPrecision>(
            showSelectedIcon: false,
            segments: [
              for (final precision in LocationPrecision.values)
                ButtonSegment<LocationPrecision>(
                  value: precision,
                  label: Text(precision.label(s)),
                ),
            ],
            selected: <LocationPrecision>{app.locationPrecision},
            onSelectionChanged: (selection) =>
                app.setLocationPrecision(selection.first),
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
      ),
    );
  }

  Widget _relaysCard(Strings s) {
    return _section(
      title: s.tr('relays'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _relays,
            minLines: 3,
            maxLines: 6,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(hintText: s.tr('relaysHint')),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _saveRelays, child: Text(s.save)),
          ),
        ],
      ),
    );
  }

  Widget _dangerCard(Strings s) {
    return _section(
      title: s.tr('deleteMyData'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tr('deleteMyDataBody'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('settings_delete_my_data'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
              ),
              onPressed: _confirmDelete,
              child: Text(s.delete),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aboutCard(Strings s) {
    return _section(
      title: s.tr('about'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.tr('aboutBody'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'EmoSphere v0.1.0',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
