// EmoSphere localization — a small CZ/EN dictionary for every user-facing text.
//
// Usage in widgets:
//   final s = Strings(app.language);
//   Text(s.tr('checkin.title'))
//   Text(s.checkinTitle)   // equivalent named getter
//
// Key namespaces: common.*, onb.*, checkin.*, hist.*, home.*, nav.* and the
// legacy flat keys kept for the named getters. test/strings_test.dart checks
// that every `tr('…')` key used in lib/ exists here in both languages.

/// Localized strings for one language (`cs` or `en`).
class Strings {
  /// Creates the strings of [code] (`'cs'` or `'en'`); anything else is Czech.
  const Strings(String code) : this._(code == 'en' ? 'en' : 'cs');

  const Strings._(this.code);

  /// Language code (`'cs'` or `'en'`).
  final String code;

  /// Alias of [code] used by widgets (`Strings(app.language)`).
  String get language => code;

  /// Supported language codes.
  static const List<String> supportedCodes = <String>['cs', 'en'];

  /// Czech strings.
  static const Strings cs = Strings._('cs');

  /// English strings.
  static const Strings en = Strings._('en');

  /// Returns the strings of [code] (falls back to Czech).
  static Strings of(String? code) => code == 'en' ? en : cs;

  /// Whether these strings are English.
  bool get isEnglish => code == 'en';

  /// Raw dictionary lookup.
  String t(String key) {
    final entry = _values[key];
    if (entry == null) {
      return key;
    }
    return entry[code] ?? entry['en'] ?? entry['cs'] ?? key;
  }

  /// Dot-notation lookup used by the screens (`s.tr('checkin.title')`).
  String tr(String key) => t(key);

  /// `true` when [key] exists in the dictionary (used by tests).
  bool hasKey(String key) => _values.containsKey(key);

  // -- App ---------------------------------------------------------------
  String get appName => t('appName');
  String get tagline => t('tagline');

  // -- Common ------------------------------------------------------------
  String get continueLabel => t('continue');
  String get back => t('back');
  String get cancel => t('cancel');
  String get save => t('save');
  String get delete => t('delete');
  String get close => t('close');
  String get send => t('send');
  String get retry => t('retry');
  String get copy => t('copy');
  String get copied => t('copied');
  String get share => t('share');
  String get add => t('add');
  String get remove => t('remove');
  String get done => t('done');
  String get skip => t('skip');
  String get loading => t('loading');
  String get errorGeneric => t('errorGeneric');
  String get yes => t('yes');
  String get no => t('no');
  String get confirm => t('confirm');

  // -- Onboarding --------------------------------------------------------
  String get onboardingTitle1 => t('onb1Title');
  String get onboardingBody1 => t('onb1Body');
  String get onboardingTitle2 => t('onb2Title');
  String get onboardingBody2 => t('onb2Body');
  String get onboardingTitle3 => t('onb3Title');
  String get onboardingBody3 => t('onb3Body');
  String get generateKey => t('generateKey');
  String get importKey => t('importKey');
  String get importHint => t('importHint');
  String get importAction => t('importAction');
  String get savedKeyCheck => t('savedKeyCheck');
  String get start => t('start');
  String get keyWarning => t('keyWarning');
  String get webKeyNote => t('webKeyNote');
  String get keyCreated => t('keyCreated');
  String get invalidKey => t('invalidKey');
  String get myNsec => t('myNsec');

  // -- Check-in ----------------------------------------------------------
  String get checkinTitle => t('checkinTitle');
  String get checkinSubtitle => t('checkinSubtitle');
  String get intensity => t('intensity');
  String get intensityLow => t('intensityLow');
  String get intensityHigh => t('intensityHigh');
  String get noteLabel => t('noteLabel');
  String get noteHint => t('noteHint');
  String get location => t('location');
  String get locationOff => t('locationOff');
  String get locationArea => t('locationArea');
  String get locationCity => t('locationCity');
  String get locationPrivacy => t('locationPrivacy');
  String get publish => t('publish');
  String get published => t('published');
  String get publishFailed => t('publishFailed');
  String get noIdentity => t('noIdentity');
  String get checkingIn => t('checkingIn');

  // -- Map ---------------------------------------------------------------
  String get map => t('map');
  String get legend => t('legend');
  String get mapEmpty => t('mapEmpty');
  String get cellDetail => t('cellDetail');
  String get tapCellHint => t('tapCellHint');
  String get checkInsShort => t('checkInsShort');
  String windowLabel(String windowKey) => t('window_$windowKey');

  // -- Feed --------------------------------------------------------------
  String get feed => t('feed');
  String get friendsSection => t('friendsSection');
  String get worldSection => t('worldSection');
  String get feedEmpty => t('feedEmpty');
  String get friendsEmptyFeed => t('friendsEmptyFeed');

  // -- Friends -----------------------------------------------------------
  String get friends => t('friends');
  String get addFriend => t('addFriend');
  String get friendNpub => t('friendNpub');
  String get myNpub => t('myNpub');
  String get qrShare => t('qrShare');
  String get friendsEmpty => t('friendsEmpty');
  String get invalidNpub => t('invalidNpub');
  String get friendAdded => t('friendAdded');
  String get friendRemoved => t('friendRemoved');

  // -- History -----------------------------------------------------------
  String get history => t('history');
  String get myCheckins => t('myCheckins');
  String get stats => t('stats');
  String get byEmotion => t('byEmotion');
  String get byDay => t('byDay');
  String get totalCheckins => t('totalCheckins');
  String get historyEmpty => t('historyEmpty');

  // -- Settings ----------------------------------------------------------
  String get settings => t('settings');
  String get profile => t('profile');
  String get relays => t('relays');
  String get relaysHint => t('relaysHint');
  String get relaysSaved => t('relaysSaved');
  String get locationPrecision => t('locationPrecision');
  String get languageLabel => t('language');
  String get keyBackup => t('keyBackup');
  String get deleteMyData => t('deleteMyData');
  String get deleteMyDataBody => t('deleteMyDataBody');
  String get deleted => t('deleted');
  String get about => t('about');
  String get aboutBody => t('aboutBody');
  String get version => t('version');

  /// "12 check-ins" with Czech plural rules.
  String checkinsCount(int count) {
    if (isEnglish) {
      return '$count ${count == 1 ? 'check-in' : 'check-ins'}';
    }
    if (count == 1) {
      return '1 check-in';
    }
    if (count >= 2 && count <= 4) {
      return '$count check-iny';
    }
    return '$count check-inů';
  }

  /// Relative time: "právě teď", "před 5 min", "před 3 h", "včera", "před 4 dny".
  String timeAgo(DateTime when, {DateTime? now}) {
    final reference = (now ?? DateTime.now()).toUtc();
    final difference = reference.difference(when.toUtc());
    if (difference.inSeconds < 60) {
      return t('justNow');
    }
    if (difference.inMinutes < 60) {
      return isEnglish
          ? '${difference.inMinutes} min ago'
          : 'před ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return isEnglish
          ? '${difference.inHours} h ago'
          : 'před ${difference.inHours} h';
    }
    if (difference.inDays == 1) {
      return t('yesterday');
    }
    if (difference.inDays < 30) {
      return isEnglish
          ? '${difference.inDays} days ago'
          : 'před ${difference.inDays} dny';
    }
    final local = when.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day.$month.${local.year}';
  }

  static const Map<String, Map<String, String>> _values =
      <String, Map<String, String>>{
    'appName': <String, String>{'cs': 'EmoSphere', 'en': 'EmoSphere'},
    'tagline': <String, String>{
      'cs': 'Podívej se, jak se svět právě teď cítí.',
      'en': 'See how the world feels right now.',
    },
    'continue': <String, String>{'cs': 'Pokračovat', 'en': 'Continue'},
    'back': <String, String>{'cs': 'Zpět', 'en': 'Back'},
    'cancel': <String, String>{'cs': 'Zrušit', 'en': 'Cancel'},
    'save': <String, String>{'cs': 'Uložit', 'en': 'Save'},
    'delete': <String, String>{'cs': 'Smazat', 'en': 'Delete'},
    'close': <String, String>{'cs': 'Zavřít', 'en': 'Close'},
    'send': <String, String>{'cs': 'Odeslat', 'en': 'Send'},
    'retry': <String, String>{'cs': 'Zkusit znovu', 'en': 'Retry'},
    'copy': <String, String>{'cs': 'Kopírovat', 'en': 'Copy'},
    'copied': <String, String>{'cs': 'Zkopírováno', 'en': 'Copied'},
    'share': <String, String>{'cs': 'Sdílet', 'en': 'Share'},
    'add': <String, String>{'cs': 'Přidat', 'en': 'Add'},
    'remove': <String, String>{'cs': 'Odebrat', 'en': 'Remove'},
    'done': <String, String>{'cs': 'Hotovo', 'en': 'Done'},
    'skip': <String, String>{'cs': 'Přeskočit', 'en': 'Skip'},
    'loading': <String, String>{'cs': 'Načítám…', 'en': 'Loading…'},
    'errorGeneric': <String, String>{
      'cs': 'Něco se pokazilo.',
      'en': 'Something went wrong.',
    },
    'yes': <String, String>{'cs': 'Ano', 'en': 'Yes'},
    'no': <String, String>{'cs': 'Ne', 'en': 'No'},
    'confirm': <String, String>{'cs': 'Potvrdit', 'en': 'Confirm'},
    'onb1Title': <String, String>{
      'cs': 'Vítej v EmoSphere',
      'en': 'Welcome to EmoSphere',
    },
    'onb1Body': <String, String>{
      'cs': 'EmoSphere je světová mapa nálad na protokolu Nostr. '
          'Bez registrace, bez e-mailu, bez jména.',
      'en': 'EmoSphere is a global mood map built on the Nostr protocol. '
          'No sign-up, no email, no name.',
    },
    'onb2Title': <String, String>{
      'cs': 'Tvůj klíč, tvá identita',
      'en': 'Your key, your identity',
    },
    'onb2Body': <String, String>{
      'cs': 'Identitu tvoří klíč, který zůstává jen v tvém zařízení. '
          'Nikdo ho za tebe nemůže obnovit.',
      'en': 'Your identity is a key that stays on your device. '
          'Nobody can recover it for you.',
    },
    'onb3Title': <String, String>{'cs': 'Záloha klíče', 'en': 'Key backup'},
    'onb3Body': <String, String>{
      'cs': 'Ulož si klíč na bezpečné místo. Bez něj o svou identitu '
          'navždy přijdeš.',
      'en': 'Store your key somewhere safe. Without it you lose your '
          'identity forever.',
    },
    'generateKey': <String, String>{
      'cs': 'Vygenerovat nový klíč',
      'en': 'Generate a new key',
    },
    'importKey': <String, String>{
      'cs': 'Mám už klíč (nsec)',
      'en': 'I already have a key (nsec)',
    },
    'importHint': <String, String>{
      'cs': 'Vlož svůj nsec klíč',
      'en': 'Paste your nsec key',
    },
    'importAction': <String, String>{
      'cs': 'Obnovit identitu',
      'en': 'Restore identity',
    },
    'savedKeyCheck': <String, String>{
      'cs': 'Klíč mám uložený',
      'en': 'I saved my key',
    },
    'start': <String, String>{'cs': 'Začít', 'en': 'Get started'},
    'keyWarning': <String, String>{
      'cs': 'Klíč nikomu nesděluj. Kdokoli s ním může mluvit za tebe.',
      'en': 'Never share your key. Anyone with it can act as you.',
    },
    'webKeyNote': <String, String>{
      'cs': 'Ve webové verzi se klíč ukládá do úložiště prohlížeče. '
          'Na sdíleném počítači ho po použití smaž.',
      'en': 'In the web version the key is stored in browser storage. '
          'On a shared computer, delete it when you finish.',
    },
    'keyCreated': <String, String>{
      'cs': 'Klíč je vytvořený.',
      'en': 'Your key is ready.',
    },
    'invalidKey': <String, String>{
      'cs': 'Tenhle klíč není platný.',
      'en': 'That key is not valid.',
    },
    'myNsec': <String, String>{
      'cs': 'Můj nsec (tajný klíč)',
      'en': 'My nsec (secret key)',
    },
    'checkinTitle': <String, String>{
      'cs': 'Jak se cítíš?',
      'en': 'How do you feel?',
    },
    'checkinSubtitle': <String, String>{
      'cs': 'Vyber emoci',
      'en': 'Pick an emotion',
    },
    'intensity': <String, String>{'cs': 'Intenzita', 'en': 'Intensity'},
    'intensityLow': <String, String>{'cs': 'slabá', 'en': 'mild'},
    'intensityHigh': <String, String>{'cs': 'silná', 'en': 'strong'},
    'noteLabel': <String, String>{
      'cs': 'Poznámka (nepovinná, veřejná)',
      'en': 'Note (optional, public)',
    },
    'noteHint': <String, String>{
      'cs': 'Co se děje?',
      'en': 'What is going on?',
    },
    'location': <String, String>{'cs': 'Lokalita', 'en': 'Location'},
    'locationOff': <String, String>{'cs': 'Vypnuto', 'en': 'Off'},
    'locationArea': <String, String>{'cs': 'Oblast', 'en': 'Area'},
    'locationCity': <String, String>{'cs': 'Město', 'en': 'City'},
    'locationPrivacy': <String, String>{
      'cs': 'Přesná poloha se nikdy neposílá — jen hrubá oblast.',
      'en': 'Exact position is never sent — only a coarse area.',
    },
    'publish': <String, String>{
      'cs': 'Odeslat check-in',
      'en': 'Send check-in',
    },
    'published': <String, String>{'cs': 'Odesláno!', 'en': 'Sent!'},
    'publishFailed': <String, String>{
      'cs': 'Odeslání se nepovedlo.',
      'en': 'Sending failed.',
    },
    'noIdentity': <String, String>{
      'cs': 'Nejdřív si vytvoř klíč.',
      'en': 'Create a key first.',
    },
    'checkingIn': <String, String>{
      'cs': 'Odesílám…',
      'en': 'Sending…',
    },
    'map': <String, String>{'cs': 'Mapa', 'en': 'Map'},
    'legend': <String, String>{'cs': 'Legenda', 'en': 'Legend'},
    'mapEmpty': <String, String>{
      'cs': 'V tomto okně zatím nikdo nic nesdílel.',
      'en': 'Nobody shared anything in this window yet.',
    },
    'cellDetail': <String, String>{'cs': 'Detail buňky', 'en': 'Cell detail'},
    'tapCellHint': <String, String>{
      'cs': 'Klepni na buňku a uvidíš rozpad emocí.',
      'en': 'Tap a cell to see the emotion breakdown.',
    },
    'checkInsShort': <String, String>{'cs': 'check-inů', 'en': 'check-ins'},
    'window_hours1': <String, String>{'cs': '1 h', 'en': '1 h'},
    'window_hours24': <String, String>{'cs': '24 h', 'en': '24 h'},
    'window_days7': <String, String>{'cs': '7 dní', 'en': '7 days'},
    'feed': <String, String>{'cs': 'Feed', 'en': 'Feed'},
    'friendsSection': <String, String>{
      'cs': 'Moji blízcí',
      'en': 'My close ones',
    },
    'worldSection': <String, String>{
      'cs': 'Právě teď ve světě',
      'en': 'Right now in the world',
    },
    'feedEmpty': <String, String>{
      'cs': 'Zatím žádné check-iny.',
      'en': 'No check-ins yet.',
    },
    'friendsEmptyFeed': <String, String>{
      'cs': 'Tvoji blízcí zatím nic nesdíleli.',
      'en': 'Your close ones have not shared anything yet.',
    },
    'friends': <String, String>{'cs': 'Přátelé', 'en': 'Friends'},
    'addFriend': <String, String>{
      'cs': 'Přidat přítele',
      'en': 'Add a friend',
    },
    'friendNpub': <String, String>{
      'cs': 'npub přítele',
      'en': "Friend's npub",
    },
    'myNpub': <String, String>{'cs': 'Můj npub', 'en': 'My npub'},
    'qrShare': <String, String>{
      'cs': 'Naskenuj a přidej si mě',
      'en': 'Scan to add me',
    },
    'friendsEmpty': <String, String>{
      'cs': 'Zatím žádní přátelé.',
      'en': 'No friends yet.',
    },
    'invalidNpub': <String, String>{
      'cs': 'Tohle není platný npub.',
      'en': 'That is not a valid npub.',
    },
    'friendAdded': <String, String>{
      'cs': 'Přítel přidán.',
      'en': 'Friend added.',
    },
    'friendRemoved': <String, String>{
      'cs': 'Přítel odebrán.',
      'en': 'Friend removed.',
    },
    'history': <String, String>{'cs': 'Historie', 'en': 'History'},
    'myCheckins': <String, String>{
      'cs': 'Moje check-iny',
      'en': 'My check-ins',
    },
    'stats': <String, String>{'cs': 'Statistiky', 'en': 'Statistics'},
    'byEmotion': <String, String>{'cs': 'Podle emocí', 'en': 'By emotion'},
    'byDay': <String, String>{'cs': 'Podle dnů', 'en': 'By day'},
    'totalCheckins': <String, String>{
      'cs': 'Celkem check-inů',
      'en': 'Total check-ins',
    },
    'historyEmpty': <String, String>{
      'cs': 'Zatím nemáš žádné check-iny.',
      'en': 'You have no check-ins yet.',
    },
    'settings': <String, String>{'cs': 'Nastavení', 'en': 'Settings'},
    'profile': <String, String>{'cs': 'Profil', 'en': 'Profile'},
    'relays': <String, String>{'cs': 'Relaye', 'en': 'Relays'},
    'relaysHint': <String, String>{
      'cs': 'Jeden wss:// odkaz na řádek',
      'en': 'One wss:// URL per line',
    },
    'relaysSaved': <String, String>{
      'cs': 'Relaye uloženy.',
      'en': 'Relays saved.',
    },
    'locationPrecision': <String, String>{
      'cs': 'Přesnost lokace',
      'en': 'Location precision',
    },
    'language': <String, String>{'cs': 'Jazyk', 'en': 'Language'},
    'keyBackup': <String, String>{'cs': 'Záloha klíče', 'en': 'Key backup'},
    'deleteMyData': <String, String>{
      'cs': 'Smazat moje data',
      'en': 'Delete my data',
    },
    'deleteMyDataBody': <String, String>{
      'cs': 'Odešle se žádost o smazání (NIP-09) a tvoje check-iny '
          'zmizí z relayů. Akci nelze vzít zpět.',
      'en': 'A deletion request (NIP-09) is published and your check-ins '
          'disappear from relays. This cannot be undone.',
    },
    'deleted': <String, String>{'cs': 'Smazáno.', 'en': 'Deleted.'},
    'about': <String, String>{'cs': 'O aplikaci', 'en': 'About'},
    'aboutBody': <String, String>{
      'cs': 'EmoSphere je opensource mapa nálad na protokolu Nostr.',
      'en': 'EmoSphere is an open source mood map built on Nostr.',
    },
    'version': <String, String>{'cs': 'Verze', 'en': 'Version'},
    'justNow': <String, String>{'cs': 'právě teď', 'en': 'just now'},
    'yesterday': <String, String>{'cs': 'včera', 'en': 'yesterday'},

    // -- Dot-notation keys (looked up via `tr('…')`) ------------------------
    'common.npubCopied': <String, String>{
      'cs': 'npub zkopírováno',
      'en': 'npub copied',
    },
    'common.nsecCopied': <String, String>{
      'cs': 'nsec zkopírováno',
      'en': 'nsec copied',
    },
    'onb.next': <String, String>{'cs': 'Pokračovat', 'en': 'Continue'},
    'onb.back': <String, String>{'cs': 'Zpět', 'en': 'Back'},
    'onb.finish': <String, String>{'cs': 'Dokončit', 'en': 'Finish'},
    'onb.step1.title': <String, String>{
      'cs': 'Vítej v EmoSphere',
      'en': 'Welcome to EmoSphere',
    },
    'onb.step1.body': <String, String>{
      'cs': 'EmoSphere je světová mapa nálad postavená na protokolu Nostr. '
          'Bez registrace, bez e-mailu, bez jména.',
      'en': 'EmoSphere is a global mood map built on the Nostr protocol. '
          'No sign-up, no email, no name.',
    },
    'onb.step1.p1': <String, String>{
      'cs': 'Řekni světu, jak se cítíš — jedním klepnutím.',
      'en': 'Tell the world how you feel — in one tap.',
    },
    'onb.step1.p2': <String, String>{
      'cs': 'Sleduj náladu planety v reálném čase.',
      'en': 'Watch the mood of the planet in real time.',
    },
    'onb.step1.p3': <String, String>{
      'cs': 'Lokalita zůstává hrubá. Přesná poloha se nikdy neposílá.',
      'en': 'Location stays coarse. The exact position is never sent.',
    },
    'onb.step2.title': <String, String>{
      'cs': 'Tvůj klíč, tvá identita',
      'en': 'Your key, your identity',
    },
    'onb.step2.body': <String, String>{
      'cs': 'Identita je klíč, který zůstává jen v tvém zařízení. '
          'Nikdo ho za tebe nemůže obnovit.',
      'en': 'Your identity is a key that stays on your device. '
          'Nobody can recover it for you.',
    },
    'onb.step2.generate': <String, String>{
      'cs': 'Vygenerovat nový klíč',
      'en': 'Generate a new key',
    },
    'onb.step2.generating': <String, String>{
      'cs': 'Generuji…',
      'en': 'Generating…',
    },
    'onb.step2.done': <String, String>{
      'cs': 'Klíč je připravený — můžeš pokračovat.',
      'en': 'Your key is ready — you can continue.',
    },
    'onb.step2.npubLabel': <String, String>{
      'cs': 'Tvůj veřejný klíč (npub)',
      'en': 'Your public key (npub)',
    },
    'onb.step2.import': <String, String>{
      'cs': 'Mám už klíč (nsec)',
      'en': 'I already have a key (nsec)',
    },
    'onb.step2.importHint': <String, String>{
      'cs': 'Vlož svůj nsec klíč',
      'en': 'Paste your nsec key',
    },
    'onb.step2.importAction': <String, String>{
      'cs': 'Obnovit identitu',
      'en': 'Restore identity',
    },
    'onb.step2.importBad': <String, String>{
      'cs': 'Tenhle klíč není platný.',
      'en': 'That key is not valid.',
    },
    'onb.step3.title': <String, String>{
      'cs': 'Záloha klíče',
      'en': 'Key backup',
    },
    'onb.step3.body': <String, String>{
      'cs': 'Ulož si klíč na bezpečné místo. Bez něj o svou identitu '
          'navždy přijdeš.',
      'en': 'Store your key somewhere safe. Without it you lose your '
          'identity forever.',
    },
    'onb.step3.nsecLabel': <String, String>{
      'cs': 'Tvůj nsec (tajný klíč)',
      'en': 'Your nsec (secret key)',
    },
    'onb.step3.qrHint': <String, String>{
      'cs': 'Naskenuj QR kód a ulož si klíč.',
      'en': 'Scan the QR code to save your key.',
    },
    'onb.step3.confirm': <String, String>{
      'cs': 'Klíč mám uložený',
      'en': 'I saved my key',
    },
    'onb.step3.warning': <String, String>{
      'cs': 'Klíč nikomu nesděluj. Kdokoli s ním může mluvit za tebe.',
      'en': 'Never share your key. Anyone with it can act as you.',
    },
    'checkin.title': <String, String>{
      'cs': 'Jak se cítíš?',
      'en': 'How do you feel?',
    },
    'checkin.intensity': <String, String>{
      'cs': 'Intenzita',
      'en': 'Intensity',
    },
    'checkin.noteHint': <String, String>{
      'cs': 'Co se děje? (nepovinné, veřejné)',
      'en': 'What is going on? (optional, public)',
    },
    'checkin.location': <String, String>{'cs': 'Lokalita', 'en': 'Location'},
    'checkin.locOff': <String, String>{'cs': 'Vypnuto', 'en': 'Off'},
    'checkin.locArea': <String, String>{'cs': 'Oblast', 'en': 'Area'},
    'checkin.locCity': <String, String>{'cs': 'Město', 'en': 'City'},
    'checkin.locHint': <String, String>{
      'cs': 'Přesná poloha se nikdy neposílá — jen hrubá oblast.',
      'en': 'The exact position is never sent — only a coarse area.',
    },
    'checkin.send': <String, String>{'cs': 'Odeslat', 'en': 'Send'},
    'checkin.sending': <String, String>{'cs': 'Odesílám…', 'en': 'Sending…'},
    'checkin.sent': <String, String>{'cs': 'Odesláno!', 'en': 'Sent!'},
    'checkin.failed': <String, String>{
      'cs': 'Odeslání se nepovedlo. Zkus to znovu.',
      'en': 'Sending failed. Try again.',
    },
    'hist.title': <String, String>{
      'cs': 'Moje check-iny',
      'en': 'My check-ins',
    },
    'hist.empty': <String, String>{
      'cs': 'Zatím nemáš žádné check-iny.',
      'en': 'You have no check-ins yet.',
    },
    'hist.total': <String, String>{
      'cs': 'Celkem check-inů',
      'en': 'Total check-ins',
    },
    'hist.now': <String, String>{'cs': 'právě teď', 'en': 'just now'},
    'hist.minAgo': <String, String>{'cs': 'před {n} min', 'en': '{n} min ago'},
    'hist.hAgo': <String, String>{'cs': 'před {n} h', 'en': '{n} h ago'},
    'hist.dAgo': <String, String>{'cs': 'před {n} dny', 'en': '{n} days ago'},
    'home.fab': <String, String>{
      'cs': 'Jak se cítíš?',
      'en': 'How do you feel?',
    },
    'nav.map': <String, String>{'cs': 'Mapa', 'en': 'Map'},
    'nav.feed': <String, String>{'cs': 'Feed', 'en': 'Feed'},
    'nav.history': <String, String>{'cs': 'Historie', 'en': 'History'},
    'nav.settings': <String, String>{'cs': 'Nastavení', 'en': 'Settings'},
  };
}
