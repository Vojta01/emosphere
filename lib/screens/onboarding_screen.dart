import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/i18n/strings.dart';
import '../core/state/app_state.dart';
import '../theme/app_theme.dart';

/// First-run onboarding: welcome, key generation, key backup (+ import).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.state,
    required this.s,
    required this.onDone,
  });

  final AppState state;
  final Strings s;
  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _stepCount = 3;

  late int _step;
  late final PageController _pages;
  final TextEditingController _import = TextEditingController();
  bool _generating = false;
  bool _importing = false;
  bool _backupConfirmed = false;
  bool _showImport = false;

  @override
  void initState() {
    super.initState();
    // A returning user with a key starts directly at the backup step.
    _step = widget.state.hasIdentity ? 2 : 0;
    _pages = PageController(initialPage: _step);
  }

  @override
  void dispose() {
    _pages.dispose();
    _import.dispose();
    super.dispose();
  }

  void _goTo(int step) {
    setState(() => _step = step);
    _pages.animateToPage(
      step,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _generateKey() async {
    setState(() => _generating = true);
    await widget.state.generateIdentity();
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _generating = false);
  }

  Future<void> _importKey() async {
    final value = _import.text.trim();
    if (value.isEmpty) return;
    setState(() => _importing = true);
    final ok = await widget.state.importIdentity(value);
    if (!mounted) return;
    setState(() => _importing = false);
    if (ok) {
      HapticFeedback.mediumImpact();
      widget.onDone();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.s.tr('onb.step2.importBad'))),
      );
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) => setState(() => _step = index),
                  children: [_welcome(s), _key(s), _backup(s)],
                ),
              ),
              _footer(s),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Row(
        children: [
          Expanded(child: _stepIndicator()),
          const SizedBox(width: 14),
          _languagePill(),
        ],
      ),
    );
  }

  Widget _stepIndicator() {
    return Row(
      children: [
        for (var i = 0; i < _stepCount; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i <= _step
                    ? AppTheme.accent
                    : Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i < _stepCount - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }

  /// Compact CZ/EN switcher — visible from the very first screen, so a
  /// non-Czech visitor is never forced through a Czech-only onboarding.
  Widget _languagePill() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          _languageOption('cs', 'Čeština'),
          _languageOption('en', 'English'),
        ],
      ),
    );
  }

  Widget _languageOption(String code, String label) {
    final selected = widget.state.language == code;
    return GestureDetector(
      key: Key('onb_lang_$code'),
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.state.setLanguage(code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }

  Widget _welcome(Strings s) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.55),
                  AppTheme.accent.withValues(alpha: 0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.35),
                  blurRadius: 60,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Center(
              child: Text('🌍', style: TextStyle(fontSize: 64)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            s.tr('onb.step1.title'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            s.tr('onb.step1.body'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 30),
          _feature(Icons.auto_awesome, s.tr('onb.step1.p1')),
          _feature(Icons.public, s.tr('onb.step1.p2')),
          _feature(Icons.lock_outline, s.tr('onb.step1.p3')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _key(Strings s) {
    final hasIdentity = widget.state.hasIdentity;
    final npub = widget.state.npub ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            s.tr('onb.step2.title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.tr('onb.step2.body'),
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 26),
          if (!hasIdentity)
            Center(
              child: FilledButton.icon(
                key: const Key('onb_generate'),
                onPressed: _generating ? null : _generateKey,
                icon: _generating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.key),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _generating
                        ? s.tr('onb.step2.generating')
                        : s.tr('onb.step2.generate'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          if (hasIdentity)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 18,
                        color: Color(0xFF4ADE80),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.tr('onb.step2.done'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4ADE80),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    s.tr('onb.step2.npubLabel'),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          npub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _copy(npub, s.tr('common.npubCopied')),
                        icon: const Icon(Icons.copy, size: 16),
                        color: AppTheme.accent,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 22),
          Center(
            child: TextButton.icon(
              key: const Key('onb_show_import'),
              onPressed: () => setState(() => _showImport = !_showImport),
              icon: Icon(
                _showImport ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(s.tr('onb.step2.import')),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.65),
              ),
            ),
          ),
          if (_showImport) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('onb_import_field'),
              controller: _import,
              obscureText: true,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white,
              ),
              decoration: InputDecoration(
                hintText: s.tr('onb.step2.importHint'),
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.tonal(
              key: const Key('onb_import'),
              onPressed: _importing ? null : _importKey,
              child: Text(s.tr('onb.step2.importAction')),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _backup(Strings s) {
    final nsec = widget.state.nsec ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            s.tr('onb.step3.title'),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            s.tr('onb.step3.body'),
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.tr('onb.step3.nsecLabel'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFFBBF24),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _copy(nsec, s.tr('common.nsecCopied')),
                      icon: const Icon(Icons.copy, size: 16),
                      color: AppTheme.accent,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SelectableText(
                  nsec,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                // Transparent Material: ListTile paints ink splashes on the
                // nearest Material ancestor, the decorated card above is not
                // one (framework asserts otherwise in debug builds).
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: _backupConfirmed,
                    onChanged: (value) =>
                        setState(() => _backupConfirmed = value ?? false),
                    title: Text(
                      s.tr('onb.step3.confirm'),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    activeColor: AppTheme.accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: QrImageView(
                data: nsec,
                version: QrVersions.auto,
                size: 190,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              s.tr('onb.step3.qrHint'),
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFFBBF24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s.tr('onb.step3.warning'),
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: const Color(0xFFFBBF24).withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _footer(Strings s) {
    final canContinue = switch (_step) {
      0 => true,
      1 => widget.state.hasIdentity,
      _ => _backupConfirmed,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Row(
        children: [
          if (_step > 0) ...[
            TextButton(
              onPressed: () => _goTo(_step - 1),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withValues(alpha: 0.6),
              ),
              child: Text(s.tr('onb.back')),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: SizedBox(
              height: 52,
              child: FilledButton(
                key: const Key('onb_next'),
                onPressed: canContinue
                    ? () {
                        if (_step >= _stepCount - 1) {
                          widget.onDone();
                        } else {
                          _goTo(_step + 1);
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  disabledBackgroundColor: Colors.white.withValues(alpha: 0.08),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _step >= _stepCount - 1
                      ? s.tr('onb.finish')
                      : s.tr('onb.next'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
