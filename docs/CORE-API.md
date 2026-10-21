# EmoSphere core API (card 1/7)

Stable interface the follow-up cards build on. Paths are relative to the repo
root. Everything listed here is covered by `flutter analyze` (clean) and
`flutter test` (97 tests green as of commit `style: dart format…`).

## Theme — `lib/theme/app_theme.dart`

```dart
AppTheme.accent              // Color(0xFF6366F1)
AppTheme.backgroundGradient  // const LinearGradient #0B1020 → #0E1430
AppTheme.surface             // #141A31 (cards), surfaceHigh #11162C (sheets/nav)
AppTheme.border, fieldFill
AppTheme.emotionColors       // 8 colours in canonical Emotion order (legend)
AppTheme.glow(color)         // soft emotion glow box shadows
AppTheme.glassDecoration({radius, tint, opacity, glowColor})
AppTheme.dark()              // MaterialApp ThemeData (use in main.dart)
GlassCard(child:, padding:, radius:, opacity:, tint:, glowColor:, onTap:)
```

## Models — `lib/core/models/`

- `Emotion` (enum, `emotion.dart`): `slug`, `color`, `labelCz`, `labelEn`,
  `emoji`, `label('cs'|'en')`, `Emotion.fromSlug(String?)`. Slugs are stable
  identifiers written into Nostr events — never rename them.
- `CheckinEvent` (`checkin.dart`): `id`, `pubkey`, `emotion`, `intensity`
  (1–5), `note` (max 140), `geohash` (nullable), `createdAt` (UTC).
  - `static const int kindValue = 1074`, `hashtag = 'emosphere'`,
    `maxNoteLength = 140`, `defaultIntensity = 3`
  - `toNostrEvent(NostrKeyPairs keys, {DateTime? createdAt})` — signed kind
    1074 event; tags `t=emosphere`, `e=<slug>`, `i=<1-5>`, `g=<geohash>`
  - `static CheckinEvent? fromNostrEvent(NostrEvent)` — `null` for foreign
    events; clamps bad intensities, drops empty geohashes
  - `toJson()` / `static fromJson(Map)` — local cache
  - `buildTags(...)`, `normalizeIntensity(int)`, `normalizeNote(String)`
- `NostrProfile` (`profile.dart`): kind 0 metadata, `bestName`, `shortPubkey`.

## Nostr — `lib/core/nostr/`

`NostrService` (`nostr_service.dart`), errors thrown as `NostrException`:

```dart
NostrService({List<String>? relays, RelayChannelFactory? channelFactory,
              FlutterSecureStorage? secureStorage, readTimeout, publishTimeout})
NostrService.defaultRelays        // wss://relay.damus.io, wss://nos.lol,
                                  // wss://relay.primal.net, wss://relay.nostr.band

// identity
keyPairs, pubkeyHex, npub, nsec, hasIdentity
generateIdentity()                // Future<NostrKeyPairs>
saveIdentity(keys) / loadIdentity() / importIdentity(nsecOrHex) / clearIdentity()
static isValidPrivateKey / isValidPubkey / normalizePrivateKey / npubOf / nsecOf
static hexFromNpub / looksLikePubkey / decodeNpub

// relay
connect({relayUrls}) / disconnect() / setRelays(List<String>)
relays, isConnected, connectedRelays

// events
publishCheckin({emotion, intensity, note, geohash, createdAt})  // → CheckinEvent
publishEvent(NostrEvent, {timeout})
subscribeCheckins({since, authors, limit})   // Stream<CheckinEvent>, dedup by id
fetchCheckins({since, authors, limit, timeout})  // → newest first
fetchMyCheckins({limit})
fetchProfiles(Iterable<String> pubkeys)      // → Map<hexPubkey, NostrProfile>
deleteMyCheckins({List<CheckinEvent>? checkins})  // kind 5 (NIP-09), returns count
dispose()
static checkinFilter({since, authors, limit})    // REQ filter (kind 1074, #t)
```

`nip19.dart` (dependency-free): `decodeNpub`, `encodeNpub`, `isValidNpub`,
`normalizePubkeyInput`, `shortenKey`.

## Geo — `lib/core/geo/`

```dart
Geohash.encode(lat, lon, {precision = 5})  // areaPrecision = 3, cityPrecision = 5
Geohash.decode(geohash) → GeoPoint         // cell centre
Geohash.bounds(geohash) → GeohashBounds    // latMin/latMax/lonMin/lonMax/center
Geohash.parent(geohash, precision)         // truncation to a coarser cell

MapWindow { hours1, hours24, days7 }       // .duration, .label(lang)
dominantEmotion(Iterable<CheckinEvent>)    // weighted by intensity, deterministic
filterByWindow(events, window, {now})
aggregateByCell(events, {precision})       // → List<CellAggregate> (count desc)
aggregateWindow(events, window, {precision, now})
CellAggregate: geohash, center, count, counts, weights, dominant,
               totalWeight, shareOf(emotion)
```

## State — `lib/core/state/app_state.dart`

`AppState extends ChangeNotifier` — pass the instance to screens and listen
with `ListenableBuilder`. Create once in `main.dart`; call `init()` there.

```dart
AppState({NostrService? service, SharedPreferences? preferences})
init({bool autoSync = true})   // loads prefs + identity + cache; syncs if autoSync
dispose()

// settings
language / strings / setLanguage('cs'|'en')
locationPrecision / setLocationPrecision(LocationPrecision)
relays / setRelays(List<String>)
// LocationPrecision { off, area, city } — .geohashPrecision, .isEnabled, .label(s)

// identity
hasIdentity / pubkeyHex / npub / nsec
generateIdentity() / importIdentity(String) → bool / clearIdentity()

// check-ins
myCheckins / worldCheckins (unmodifiable, newest first)
publishCheckin({emotion, intensity, note, precision}) → CheckinEvent
refresh({includeProfiles})   // fetch my + world window + profiles
deleteMyCheckins() → int     // NIP-09
isSyncing / isConnected / connectedRelays
startLiveUpdates() / stopLiveUpdates()

// friends
friends (hex keys) / addFriend(npubOrHex) → AddFriendOutcome / removeFriend() → bool
profiles / profileOf(hex) / refreshProfiles()
```

Preference keys: `AppState.keyLanguage`, `keyLocationPrecision`, `keyRelays`,
`keyFriends`, `keyMyCheckins` (JSON cache of my check-ins). Test helper:
`SharedPreferences.setMockInitialValues({})` + `AppState(..., autoSync: false)`.

Other helpers: `lib/core/social/friends.dart` (npub add/remove/dedupe,
`AddFriendOutcome`), `lib/core/feed/feed_logic.dart` (`sortByNewest`,
`filterByAuthors`, `latestPerAuthor`, `worldFeedLimit = 50`).

## i18n — `lib/core/i18n/strings.dart`

```dart
final s = Strings(app.language);   // 'cs' | 'en' (unknown → 'cs')
s.tr('checkin.title')              // dot-notation keys used by the screens
s.t('checkinTitle')                // raw lookup (same dictionary)
s.hasKey(key)                      // test helper
s.timeAgo(utcDateTime) / s.checkinsCount(n) / named getters (s.cancel, …)
Strings.cs / Strings.en / Strings.of(code) / Strings.supportedCodes
```

Adding text = add one entry to the `_values` map (both `cs` and `en`).
`test/strings_test.dart` scans `lib/` and fails when a `tr('…')` key used in
code is missing from either language.

## Screens status (for cards 2/3)

- `lib/main.dart` — bootstrap wired: splash → onboarding (no key) →
  `HomeShell`. Keep `AppTheme.dark()` and the `AppState` lifecycle here.
- `lib/screens/home_shell.dart` — bottom nav (Mapa / Feed / Historie /
  Nastavení) + `FloatingActionButton.extended` ("Jak se cítíš?") that opens the
  check-in sheet. Passes `AppState` into the four screens.
- `lib/screens/onboarding_screen.dart` — **full** (card 2): 3 steps (welcome →
  key generation/import → nsec backup as text + QR), `PageView` with a step
  indicator, CZ/EN.
- `lib/widgets/checkin_sheet.dart` — **full** (card 2): `showCheckinSheet(...)`
  → `CheckinSheet` with 8 emotion tiles, intensity 1–5, note (140 chars),
  location picker and the send button; success = heavy haptic + animated check
  overlay, then the sheet pops with `true`. Failure keeps the sheet open and
  shows `checkin.failed`.
- `lib/screens/history_screen.dart` — **full** (card 2): timeline + per-emotion
  bars + seven-day mini chart (`_DayBucket`, dominant emotion weighted by
  intensity).
- `lib/screens/settings_screen.dart` — **full** (card 2): profile (npub copy +
  QR share), key backup (`_KeyQrDialog`: masked nsec, reveal, copy, QR),
  language, location precision, relay editor, delete my data (NIP-09) and about.
- `lib/screens/feed_screen.dart`, `map_screen.dart` — minimal scaffolds written
  for card 1 so the project compiles and runs; card 3 replaces them with the
  full versions (flutter_map tiles, friends section). Constructor signatures to
  keep: `FeedScreen({required AppState app})`,
  `MapScreen({required AppState app})`,
  `SettingsScreen({required AppState app, required Strings s})`.

## Widget-test pitfalls

- `FlutterSecureStorage` (channel
  `plugins.it_nomads.com/flutter_secure_storage`) has no handler in
  `flutter test` and its `read` future **never completes**. Any test that calls
  `AppState.init` must install a mock, or the test hangs forever:

  ```dart
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  ```

  `SharedPreferences.setMockInitialValues({})` alone is not enough. With the
  mock in place `AppState.generateIdentity()` works headless.
- `QrImageView` (qr_flutter) always builds a `LayoutBuilder`, which cannot
  answer intrinsic-dimension queries — so it must never sit inside an
  `AlertDialog` content subtree without a tight `SizedBox` wrapper around it.
- The check-in sheet animates a `CircularProgressIndicator` while sending:
  prefer explicit `pump(Duration(...))` over `pumpAndSettle()` between the tap
  and the auto-close.
- Screens are taller than the default 800×600 test surface — set a tall
  surface (`tester.binding.setSurfaceSize(const Size(500, 1600))`) so
  lazy `ListView` children are built and tappable.

## Checks

```
flutter analyze                 # clean
flutter test                    # 115 tests
dart format lib test            # Dart style (not enforced by CI, run it)
```

On this host keep heavy builds serial: `flock /tmp/emosphere-build.lock` and
`df -B1M /` ≥ 2500 MB free before `flutter build`.
