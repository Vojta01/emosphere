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
    1074 event; tags `t=emosphere`, `emotion=<slug>`, `intensity=<1-5>`,
    `g=<geohash>` (0.1.2+: full-word tags; `e`/`i` are reserved
    fixed-size tags on relays and were rejected)
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
Geohash.encode(lat, lon, {precision = 5})  // areaPrecision = 6, cityPrecision = 5
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

`heat.dart` — pure heat-layer geometry used by `map_screen.dart` (no
flutter_map import, so it stays unit-testable):

```dart
precisionForZoom(zoom)      // 1 (zoom <4) … 5 (zoom ≥12); cell ≈ 1/5 of the view
cellSizeMeters(geohash)     // mean side of the cell from Geohash.bounds
heatRadiusMeters(geohash, {factor = 0.62})  // clamped to 400 m … 2600 km
heatOpacity(count, {maxCount, min = 0.24, max = 0.74})  // logarithmic
distanceMeters(a, b)        // haversine
cellAt(cells, point, {tolerance = 1.6})     // nearest cell containing the tap
friendCellHashes(events, friendPubkeys, {required precision})
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
friendCheckins (last worldWindow, newest first) / refreshFriendCheckins()
friendCheckinsLimit = 100
profiles / profileOf(hex) / refreshProfiles()
```

`refresh()` fetches my check-ins, the world window and (when friends exist)
their check-ins plus kind 0 metadata. The live subscription merges new events
into `worldCheckins` and into `friendCheckins` when the author is a friend.

Preference keys: `AppState.keyLanguage`, `keyLocationPrecision`, `keyRelays`,
`keyFriends`, `keyMyCheckins` (JSON cache of my check-ins). Test helper:
`SharedPreferences.setMockInitialValues({})` + `AppState(..., autoSync: false)`.

Other helpers: `lib/core/social/friends.dart` (npub add/remove/dedupe,
`AddFriendOutcome` — `dedupeFriendKeys` collapses an `npub…` entry into its hex
form), `lib/core/feed/feed_logic.dart` (`sortByNewest`, `filterByAuthors`,
`latestPerAuthor`, `checkinPool`, `worldFeedLimit = 50`).

## i18n — `lib/core/i18n/strings.dart`

```dart
final s = Strings(app.language);   // 'cs' | 'en' (unknown → 'cs')
s.tr('checkin.title')              // dot-notation keys used by the screens
s.t('checkinTitle')                // raw lookup (same dictionary)
s.hasKey(key)                      // test helper
s.timeAgo(utcDateTime) / s.checkinsCount(n) / s.mapCellsCount(n) / named getters (s.cancel, …)
Strings.cs / Strings.en / Strings.of(code) / Strings.supportedCodes
```

Adding text = add one entry to the `_values` map (both `cs` and `en`).
`test/strings_test.dart` scans `lib/` and fails when a `tr('…')` key used in
code is missing from either language.

## Screens status (for cards 3+)

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
  QR share), key backup (masked nsec, reveal, copy, QR), language, location
  precision, relay editor, delete my data (NIP-09) and about. The QR dialog
  itself lives in `lib/widgets/key_qr_dialog.dart` (card 3):
  `showKeyQrDialog(context, {s, title, value, hint, copyMessage, warning,
  keyPrefix = 'settings', masked = true})` — widget keys are prefixed with
  `keyPrefix` (`<prefix>_key_value`, `_key_toggle`, `_key_copy`), so tests can
  address the dialog of a given screen.
- `lib/screens/feed_screen.dart` — **full** (card 3): "Moji blízcí" (friend
  chips with add / remove / share-npub and the latest check-in card per friend,
  kind 0 name + avatar with an initial fallback) and "Právě teď ve světě"
  (`worldFeedLimit` newest check-ins of the pool, my own excluded; card =
  emotion colour, relative time, intensity dots, note, coarse geohash). Both
  sections read `checkinPool(app.worldCheckins, app.friendCheckins)`, so a
  friend's check-in is never listed twice. Keys: `feed_add_friend`,
  `feed_share_npub`, `feed_reload_friends`, `friends_npub_field`,
  `friends_add_confirm`, `friend_chip_<short key>`.
- `lib/screens/map_screen.dart` — **full** (card 3):
  `MapScreen({required AppState app, TileProvider? tileProvider})` (the
  provider is the test seam). flutter_map 8 + OSM tiles (`darkModeTileBuilder`
  invert/hue-rotate, `errorTileCallback` swallows offline tiles), heat
  `CircleLayer` from `aggregateByCell(windowed, precision: precisionForZoom)`
  — colour = dominant emotion, radius = `heatRadiusMeters`, opacity =
  `heatOpacity` — plus a white ring on cells holding a friend check-in.
  Window switcher (1 h / 24 h / 7 d), 8-colour legend, cell count, recentre
  button, hint, and a tap → bottom sheet with the emotion breakdown and count.
  The first camera is fitted to the *raw check-in points* of the window
  (`CameraFit.coordinates`, `maxZoom: 6`) — fitting aggregated cells would open
  the map on a continent-sized cell centre, because the precision follows the
  zoom. Location shows as the published geohash: the app has no reverse
  geocoding (no city names yet).

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
- flutter_map: a tap only reaches `MapOptions.onTap` after the double-tap delay
  (250 ms). `pumpAndSettle()` does not advance the clock when nothing animates,
  so tap with `tapAt(...)`, then `pump(const Duration(milliseconds: 400))`
  before `pumpAndSettle()` — otherwise the sheet never opens and the test fails
  with "A Timer is still pending".
- flutter_map tiles: pass an in-memory `TileProvider` (a `MemoryImage` of a 1×1
  PNG) to the screen under test, or every tile request is a network call.
- `SimpleAttributionWidget` cannot wrap its text: with the test font (Ahem, all
  glyphs are square) the credit overflows a phone-sized surface and fails the
  test. `map_screen.dart` therefore draws its own compact credit chip.
- `CameraFit` runs inside the first build and calls `onPositionChanged`
  synchronously — a `setState` there throws. Store the value and rebuild from a
  post-frame callback (see `_MapScreenState._onPositionChanged`).
- Widget tests over `AppState` get their data from `test/support/
  fake_relay_service.dart` (`FakeRelayService`): it overrides the `NostrService`
  query methods *and* the `pubkeyHex` / `npub` getters, so a test can act as a
  signed-in user without secure storage or relays.

## Checks

```
flutter analyze                 # clean
flutter test                    # 151 tests
dart format lib test            # Dart style (not enforced by CI, run it)
```

On this host keep heavy builds serial: `flock /tmp/emosphere-build.lock` and
`df -B1M /` ≥ 2500 MB free before `flutter build`.
