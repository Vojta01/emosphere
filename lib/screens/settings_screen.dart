// Settings screen — relays, location precision, language, key, data.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/i18n/strings.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/key_qr_dialog.dart';
import '../widgets/user_avatar.dart';

/// Version shown in the About card — keep in sync with `pubspec.yaml`.
const String appVersionLabel = 'v0.3.2';

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
          _keyBackupCard(s, app),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (app.pubkeyHex != null) ...[
            Row(
              children: [
                UserAvatar(
                  profile: app.profileOf(app.pubkeyHex!),
                  pubkey: app.pubkeyHex!,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    app.profileOf(app.pubkeyHex!)?.bestName ??
                        s.tr('profile.name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const Key('settings_edit_profile'),
                  onPressed: () => _editProfile(app),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(s.tr('profile.edit')),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  npub == null || npub.isEmpty ? s.noIdentity : npub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
              if (npub != null && npub.isNotEmpty) ...[
                IconButton(
                  key: const Key('settings_copy_npub'),
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
                IconButton(
                  key: const Key('settings_share_npub'),
                  tooltip: s.tr('set.shareNpub'),
                  color: AppTheme.accent,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  onPressed: () => _showNpubQr(npub),
                ),
              ],
            ],
          ),
          if (npub != null && npub.isNotEmpty) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showNpubQr(npub),
                icon: const Icon(Icons.ios_share, size: 16),
                label: Text(s.tr('set.shareNpub')),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showNpubQr(String npub) async {
    HapticFeedback.lightImpact();
    await showKeyQrDialog(
      context,
      s: widget.s,
      title: widget.s.tr('profile'),
      value: npub,
      hint: widget.s.tr('set.npubQrHint'),
      copyMessage: widget.s.tr('common.npubCopied'),
      // A public key needs no masking.
      masked: false,
    );
  }

  /// Dialog that publishes a fresh kind 0 profile (name, about, picture).
  Future<void> _editProfile(AppState app) async {
    final s = widget.s;
    final me = app.pubkeyHex;
    if (me == null) {
      return;
    }
    final current = app.profileOf(me);
    final name = TextEditingController(text: current?.name ?? '');
    final about = TextEditingController(text: current?.about ?? '');
    final picture = TextEditingController(text: current?.picture ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(s.tr('profile.edit')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('profile_name_field'),
                controller: name,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: s.tr('profile.name'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('profile_about_field'),
                controller: about,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: s.tr('profile.about'),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                key: const Key('profile_picture_field'),
                controller: picture,
                maxLength: 300,
                decoration: InputDecoration(
                  labelText: s.tr('profile.picture'),
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            key: const Key('profile_save'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(s.save),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      try {
        await app.publishProfile(
          name: name.text.trim(),
          about: about.text.trim(),
          picture: picture.text.trim(),
        );
        if (mounted) {
          _snack(s.tr('profile.saved'));
        }
      } on Object {
        if (mounted) {
          _snack(s.tr('profile.saveFailed'));
        }
      }
    }
    name.dispose();
    about.dispose();
    picture.dispose();
  }

  Widget _keyBackupCard(Strings s, AppState app) {
    final hasKey = (app.nsec ?? '').isNotEmpty;
    return _section(
      title: s.tr('keyBackup'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.tr('set.keyBody'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('settings_reveal_key'),
                  onPressed: hasKey ? _showKeyBackup : null,
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: Text(s.tr('set.revealKey')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    side: BorderSide(
                      color: AppTheme.accent.withValues(alpha: 0.55),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                key: const Key('settings_copy_key'),
                tooltip: s.tr('set.copyKey'),
                color: hasKey
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.25),
                icon: const Icon(Icons.key, size: 20),
                onPressed: hasKey
                    ? () async {
                        await Clipboard.setData(
                          ClipboardData(text: app.nsec ?? ''),
                        );
                        if (mounted) {
                          _snack(s.tr('common.nsecCopied'));
                        }
                      }
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showKeyBackup() async {
    final nsec = widget.app.nsec ?? '';
    if (nsec.isEmpty) {
      _snack(widget.s.tr('noIdentity'));
      return;
    }
    HapticFeedback.lightImpact();
    await showKeyQrDialog(
      context,
      s: widget.s,
      title: widget.s.tr('keyBackup'),
      value: nsec,
      hint: widget.s.tr('set.keyQrHint'),
      copyMessage: widget.s.tr('common.nsecCopied'),
      warning: widget.s.tr('onb.step3.warning'),
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
          const SizedBox(height: 4),
          Text(
            s.tr('tagline'),
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text(
                s.tr('version'),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                appVersionLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
