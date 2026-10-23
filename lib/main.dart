// EmoSphere — app bootstrap.
//
// Flow: splash → onboarding (no key yet) → home shell (map / feed / history /
// settings). The app runs offline-first: [AppState.init] loads local state and
// starts the relay sync in the background.

import 'dart:async';

import 'package:flutter/material.dart';

import 'core/i18n/strings.dart';
import 'core/quotes/quotes.dart';
import 'core/state/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EmoSphereApp());
}

/// Root widget of the app.
class EmoSphereApp extends StatefulWidget {
  const EmoSphereApp({super.key, this.app, this.autoSync = true});

  /// Optional pre-built state; widget tests inject a prepared instance.
  final AppState? app;

  /// Tests pass `false` to keep the relay sync out of the test.
  final bool autoSync;

  @override
  State<EmoSphereApp> createState() => _EmoSphereAppState();
}

class _EmoSphereAppState extends State<EmoSphereApp>
    with WidgetsBindingObserver {
  late final AppState _app = widget.app ?? AppState();
  late final bool _ownsApp = widget.app == null;
  late final Future<void> _ready = _app.init(autoSync: widget.autoSync);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Best-effort background load of the quote library (R10/R11).
    // Deliberately not awaited by [_ready]: a slow or failed asset must
    // never block the first frame — without it the check-in flow falls
    // back to the plain confirmation.
    unawaited(_loadQuotes());
  }

  Future<void> _loadQuotes() async {
    try {
      await QuotesLibrary.load();
    } catch (_) {
      // Keep the app usable without the quotes.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsApp) {
      _app.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back from the background: relay sockets may have died silently.
    if (state == AppLifecycleState.resumed) {
      _app.handleAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EmoSphere',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _Splash();
          }
          return ListenableBuilder(
            listenable: _app,
            builder: (context, _) {
              final s = Strings(_app.language);
              // Keep onboarding open until it is explicitly finished: as soon
              // as the identity exists, the backup step (nsec + QR) must still
              // be reachable before the home shell appears.
              if (!_app.hasIdentity || !_app.onboardingComplete) {
                return OnboardingScreen(
                  state: _app,
                  s: s,
                  onDone: () => _app.completeOnboarding(),
                );
              }
              return HomeShell(app: _app);
            },
          );
        },
      ),
    );
  }
}

/// Splash while the local state loads.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🌍', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'EmoSphere',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 28),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}
