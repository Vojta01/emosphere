// EmoSphere — app bootstrap.
//
// Flow: splash → onboarding (no key yet) → home shell (map / feed / history /
// settings). The app runs offline-first: [AppState.init] loads local state and
// starts the relay sync in the background.

import 'package:flutter/material.dart';

import 'core/i18n/strings.dart';
import 'core/state/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const EmoSphereApp());
}

/// Root widget of the app.
class EmoSphereApp extends StatefulWidget {
  const EmoSphereApp({super.key});

  @override
  State<EmoSphereApp> createState() => _EmoSphereAppState();
}

class _EmoSphereAppState extends State<EmoSphereApp> {
  final AppState _app = AppState();
  late final Future<void> _ready = _app.init();

  @override
  void dispose() {
    _app.dispose();
    super.dispose();
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
              if (!_app.hasIdentity) {
                return OnboardingScreen(
                  state: _app,
                  s: s,
                  onDone: () => setState(() {}),
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
