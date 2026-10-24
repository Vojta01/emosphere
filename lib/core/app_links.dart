// Canonical public links of the project, shared by the onboarding screen,
// the settings screen and any future share affordances.
//
// Kept in one place so a domain/URL change never drifts between screens.

import 'package:url_launcher/url_launcher.dart';

/// Canonical public URLs of EmoSphere.
abstract final class AppLinks {
  /// The hosted web app (PWA) — the canonical share link.
  static const String web = 'https://emosphere.digitalni-vedomi.cz/';

  /// Source repository.
  static const String github = 'https://github.com/Vojta01/emosphere';

  /// Latest Android build (GitHub Releases).
  static const String androidApk =
      'https://github.com/Vojta01/emosphere/releases/latest';
}

/// Opens [url] in an external browser/tab.
///
/// Returns `false` when the platform refuses to handle the URL; callers may
/// ignore it (the links are a best-effort convenience).
Future<bool> openAppLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Object {
    return false;
  }
}
