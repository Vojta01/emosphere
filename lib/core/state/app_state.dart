// EmoSphere application state — the single [ChangeNotifier] the UI listens to.
//
// Public surface used by the other EmoSphere cards:
//   * identity:  hasIdentity / npub / nsec / generateIdentity() /
//                importIdentity() / clearIdentity()
//   * check-ins: myCheckins / worldCheckins / publishCheckin(...) / refresh() /
//                deleteMyCheckins()
//   * friends:   friends / addFriend() / removeFriend() / profiles / profileOf()
//   * settings:  language / setLanguage() / locationPrecision /
//                setLocationPrecision() / relays / setRelays()
//   * relay:     isConnected / connectedRelays / startLiveUpdates() /
//                stopLiveUpdates()
//
// Local settings live in SharedPreferences (on the web that is browser
// localStorage); the private key lives in flutter_secure_storage.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../geo/geohash.dart';
import '../i18n/strings.dart';
import '../models/checkin.dart';
import '../models/dm.dart';
import '../models/emotion.dart';
import '../models/profile.dart';
import '../nostr/nostr_service.dart';
import '../social/friends.dart';

/// Coarse location granularity of a check-in (SPEC: off / city / area).
enum LocationPrecision {
  /// No location is attached to check-ins.
  off(0),

  /// Geohash precision 5 — a city-sized cell (~5 km).
  city(Geohash.cityPrecision),

  /// Geohash precision 6 — a neighbourhood-sized cell (~0.5 km radius).
  area(Geohash.areaPrecision);

  const LocationPrecision(this.geohashPrecision);

  /// Geohash precision used when this mode is on (0 = location off).
  final int geohashPrecision;

  /// `true` when a geohash must be attached to a check-in.
  bool get isEnabled => this != LocationPrecision.off;

  /// Localized label ("Vypnuto" / "Oblast" / "Město").
  String label(Strings s) {
    switch (this) {
      case LocationPrecision.off:
        return s.tr('checkin.locOff');
      case LocationPrecision.area:
        return s.tr('checkin.locArea');
      case LocationPrecision.city:
        return s.tr('checkin.locCity');
    }
  }

  /// Parses a stored preference value; unknown names fall back to [off].
  static LocationPrecision fromName(String? name) {
    for (final value in LocationPrecision.values) {
      if (value.name == name) {
        return value;
      }
    }
    return LocationPrecision.off;
  }
}

/// Central application state: identity, check-ins, friends and settings.
class AppState extends ChangeNotifier {
  AppState({NostrService? service, SharedPreferences? preferences})
    : _service = service ?? NostrService(),
      _prefs = preferences;

  // -- Storage keys --------------------------------------------------------

  /// Preference key of the UI language.
  static const String keyLanguage = 'emosphere.language';

  /// Preference key of the location precision.
  static const String keyLocationPrecision = 'emosphere.locationPrecision';

  /// Preference key of the relay list.
  static const String keyRelays = 'emosphere.relays';

  /// Preference key of the friend list.
  static const String keyFriends = 'emosphere.friends';

  /// Preference key of the local my-check-ins cache.
  static const String keyMyCheckins = 'emosphere.myCheckins';

  /// Preference key of the cached kind 0 profiles.
  static const String keyProfiles = 'emosphere.profiles';

  /// Preference key of the local direct-message cache.
  static const String keyDms = 'emosphere.dms';

  /// Preference key of the per-conversation read markers.
  static const String keyDmLastRead = 'emosphere.dmLastRead';

  /// Preference key marking that the first-run onboarding (including the
  /// key backup step) has been finished on this device.
  static const String keyOnboardingComplete = 'emosphere.onboardingComplete';

  /// How far back the world feed / map loads check-ins.
  static const Duration worldWindow = Duration(days: 30);

  /// Maximum number of world check-ins kept in memory.
  static const int worldLimit = 500;

  /// Maximum number of my check-ins kept in memory (and on disk).
  static const int myCheckinsLimit = 500;

  /// Maximum number of my friends' check-ins kept in memory (card 3).
  static const int friendCheckinsLimit = 100;

  /// Maximum number of direct messages kept in memory (and on disk).
  static const int dmFetchLimit = 300;

  /// How many world-feed authors get a kind 0 profile fetch per refresh.
  static const int feedProfileLimit = 60;

  final NostrService _service;
  SharedPreferences? _prefs;

  String _language = 'cs';
  LocationPrecision _locationPrecision = LocationPrecision.off;
  final List<CheckinEvent> _myCheckins = <CheckinEvent>[];
  final List<CheckinEvent> _worldCheckins = <CheckinEvent>[];
  final List<CheckinEvent> _friendCheckins = <CheckinEvent>[];
  final Map<String, NostrProfile> _profiles = <String, NostrProfile>{};
  List<String> _friends = <String>[];
  bool _syncInProgress = false;
  bool _onboardingComplete = false;
  bool _disposed = false;
  StreamSubscription<CheckinEvent>? _liveSub;

  /// Live direct-message subscription (kind 4).
  StreamSubscription<DmMessage>? _dmSub;

  /// Decrypted direct messages, oldest first.
  final List<DmMessage> _dms = <DmMessage>[];

  /// Per-conversation read markers (counterparty hex -> ms since epoch).
  Map<String, int> _dmLastRead = <String, int>{};

  /// Pubkeys whose kind 0 metadata was already requested this session.
  final Set<String> _profileFetchAttempted = <String>{};

  /// One-shot map focus request (R4: show a check-in on the map).
  MapFocusRequest? _mapFocusRequest;
  int _mapFocusCounter = 0;

  // ---------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------

  /// Loads local state (preferences, identity, cached check-ins).
  ///
  /// With [autoSync] the relay connection and live subscription start in the
  /// background; failures are swallowed so the app always boots offline.
  /// Tests pass `autoSync: false`.
  Future<void> init({bool autoSync = true}) async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs!;
    _language = prefs.getString(keyLanguage) ?? 'cs';
    _locationPrecision = LocationPrecision.fromName(
      prefs.getString(keyLocationPrecision),
    );
    _onboardingComplete = prefs.getBool(keyOnboardingComplete) ?? false;
    _friends = dedupeFriendKeys(prefs.getStringList(keyFriends) ?? const []);
    final relays = prefs.getStringList(keyRelays);
    if (relays != null && relays.isNotEmpty) {
      _service.relays = List<String>.of(relays);
    }
    _restoreMyCheckins(prefs);
    _restoreProfiles(prefs);
    _restoreDms(prefs);
    await _service.loadIdentity();
    if (autoSync) {
      unawaited(_syncQuietly());
      startLiveUpdates();
      startDmLiveUpdates();
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _liveSub?.cancel();
    _liveSub = null;
    _dmSub?.cancel();
    _dmSub = null;
    _service.dispose();
    super.dispose();
  }

  /// Called when the app returns to the foreground.
  ///
  /// Heals relay sockets that died while the device slept (they never fire
  /// `onDone`), so the next publish does not fail on a dead connection.
  void handleAppResumed() {
    if (_disposed) {
      return;
    }
    unawaited(
      _service.refreshStaleConnections().catchError((Object _) {}),
    );
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  /// Whether a key pair exists on this device.
  bool get hasIdentity => _service.hasIdentity;

  /// Whether the first-run onboarding (incl. the key backup step) finished.
  ///
  /// While this is `false` the app keeps the user in onboarding even after a
  /// key exists, so the `nsec` backup step is always seen (or the key was
  /// imported explicitly).
  bool get onboardingComplete => _onboardingComplete;

  /// Marks the first-run onboarding as finished and persists the flag.
  Future<void> completeOnboarding() async {
    if (_onboardingComplete) return;
    _onboardingComplete = true;
    await _prefs?.setBool(keyOnboardingComplete, true);
    _notify();
  }

  /// Hex public key of the active identity.
  String? get pubkeyHex => _service.pubkeyHex;

  /// `npub...` of the active identity (for sharing).
  String? get npub => _service.npub;

  /// `nsec...` of the active identity (for the backup screen).
  String? get nsec => _service.nsec;

  /// Generates a new identity and persists it in secure storage.
  Future<void> generateIdentity() async {
    await _service.generateIdentity();
    _notify();
  }

  /// Imports an identity from an `nsec...` or hex private key.
  ///
  /// Returns `false` when the key is invalid.
  Future<bool> importIdentity(String input) async {
    try {
      await _service.importIdentity(input);
    } on NostrException {
      return false;
    }
    _notify();
    return true;
  }

  /// Removes the identity from this device (the key is not recoverable).
  Future<void> clearIdentity() async {
    await _service.clearIdentity();
    _myCheckins.clear();
    _worldCheckins.clear();
    _friendCheckins.clear();
    _profiles.clear();
    _dms.clear();
    _dmLastRead = <String, int>{};
    _profileFetchAttempted.clear();
    await _persistDms();
    // A fresh identity needs a fresh backup confirmation.
    _onboardingComplete = false;
    await _prefs?.setBool(keyOnboardingComplete, false);
    await _persistMyCheckins();
    _notify();
  }

  // ---------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------

  /// Current UI language code (`'cs'` or `'en'`).
  String get language => _language;

  /// Localized strings for the current language.
  Strings get strings => Strings(_language);

  /// Switches the UI language; stores the choice.
  Future<void> setLanguage(String code) async {
    final value = Strings.supportedCodes.contains(code) ? code : 'cs';
    if (value == _language) {
      return;
    }
    _language = value;
    await _prefs?.setString(keyLanguage, value);
    _notify();
  }

  /// Current location precision used for new check-ins.
  LocationPrecision get locationPrecision => _locationPrecision;

  /// Switches the location precision; stores the choice.
  Future<void> setLocationPrecision(LocationPrecision precision) async {
    if (precision == _locationPrecision) {
      return;
    }
    _locationPrecision = precision;
    await _prefs?.setString(keyLocationPrecision, precision.name);
    _notify();
  }

  /// Relay URLs currently in use.
  List<String> get relays => List<String>.unmodifiable(_service.relays);

  /// Replaces the relay list (empty input restores the SPEC defaults).
  Future<void> setRelays(List<String> relayUrls) async {
    final cleaned = relayUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    await _service.setRelays(cleaned);
    await _prefs?.setStringList(keyRelays, _service.relays);
    startLiveUpdates();
    _notify();
  }

  // ---------------------------------------------------------------------
  // Check-ins
  // ---------------------------------------------------------------------

  /// My check-ins, newest first.
  List<CheckinEvent> get myCheckins =>
      List<CheckinEvent>.unmodifiable(_myCheckins);

  /// Check-ins of the whole world (last [worldWindow]), newest first.
  List<CheckinEvent> get worldCheckins =>
      List<CheckinEvent>.unmodifiable(_worldCheckins);

  /// Publishes a check-in and adds it to the local lists.
  ///
  /// [precision] defaults to the current [locationPrecision] setting; when it
  /// is enabled, a coarse geohash of the current position is attached (and
  /// silently omitted when the position is unavailable).
  /// Rethrows [NostrException] when no relay accepted the event.
  Future<CheckinEvent> publishCheckin({
    required Emotion emotion,
    required int intensity,
    String note = '',
    LocationPrecision? precision,
  }) async {
    final mode = precision ?? _locationPrecision;
    final geohash = mode.isEnabled ? await _resolveGeohash(mode) : null;
    final checkin = await _service.publishCheckin(
      emotion: emotion,
      intensity: intensity,
      note: note,
      geohash: geohash,
    );
    _merge(_myCheckins, <CheckinEvent>[checkin], limit: myCheckinsLimit);
    _merge(_worldCheckins, <CheckinEvent>[checkin], limit: worldLimit);
    await _persistMyCheckins();
    _notify();
    return checkin;
  }

  /// Fetches my check-ins, the world window, my friends and their profiles.
  ///
  /// Never throws: offline use simply keeps the cached lists.
  Future<void> refresh({bool includeProfiles = true}) async {
    if (hasIdentity) {
      try {
        final mine = await _service.fetchMyCheckins(limit: myCheckinsLimit);
        _merge(_myCheckins, mine, limit: myCheckinsLimit);
        await _persistMyCheckins();
      } on NostrException {
        // Offline / relays down — keep the cache.
      }
    }
    try {
      final since = DateTime.now().toUtc().subtract(worldWindow);
      final world = await _service.fetchCheckins(
        since: since,
        limit: worldLimit,
      );
      _merge(_worldCheckins, world, limit: worldLimit);
    } on NostrException {
      // Keep whatever we already have.
    }
    if (_friends.isNotEmpty) {
      await refreshFriendCheckins();
    }
    if (includeProfiles) {
      await refreshProfiles();
    }
    if (hasIdentity) {
      await refreshDms();
    }
    _notify();
  }

  /// Deletes my check-ins on the relays (NIP-09 kind 5) and locally.
  ///
  /// Returns the number of check-ins referenced by the deletion request.
  Future<int> deleteMyCheckins() async {
    final targets = List<CheckinEvent>.of(_myCheckins);
    final deleted = await _service.deleteMyCheckins(checkins: targets);
    _myCheckins.clear();
    await _persistMyCheckins();
    _notify();
    return deleted;
  }

  /// `true` while a relay fetch is running.
  bool get isSyncing => _syncInProgress;

  /// `true` when at least one relay connection is alive.
  bool get isConnected => _service.isConnected;

  /// URLs of the currently connected relays.
  List<String> get connectedRelays => _service.connectedRelays;

  // ---------------------------------------------------------------------
  // Friends
  // ---------------------------------------------------------------------

  /// Hex public keys of my friends.
  List<String> get friends => List<String>.unmodifiable(_friends);

  /// Adds a friend from an `npub...` or hex key; stores the list.
  ///
  /// The returned [AddFriendOutcome] tells the UI what happened. A successful
  /// add fetches the friend's profile (kind 0) and their latest check-ins in
  /// the background.
  AddFriendOutcome addFriend(String input) {
    final result = addFriendKey(_friends, input);
    if (result.outcome == AddFriendOutcome.added) {
      _friends = result.keys;
      unawaited(_prefs?.setStringList(keyFriends, _friends));
      unawaited(refreshProfiles());
      unawaited(refreshFriendCheckins());
      _notify();
    }
    return result.outcome;
  }

  /// Removes a friend by `npub...` or hex key. Returns `true` when removed.
  ///
  /// The removed author's check-ins leave the friend list as well, so the feed
  /// and the map update immediately.
  bool removeFriend(String input) {
    final updated = removeFriendKey(_friends, input);
    if (updated.length == _friends.length) {
      return false;
    }
    _friends = updated;
    _friendCheckins.removeWhere(
      (checkin) => !_friends.contains(checkin.pubkey.trim().toLowerCase()),
    );
    unawaited(_prefs?.setStringList(keyFriends, _friends));
    _notify();
    return true;
  }

  /// My friends' check-ins from the last [worldWindow], newest first.
  ///
  /// Fetched by author (not part of [worldCheckins]), so the friends section of
  /// the feed keeps working when the world pool is capped by recency.
  List<CheckinEvent> get friendCheckins =>
      List<CheckinEvent>.unmodifiable(_friendCheckins);

  /// Fetches the newest check-ins of my friends from relays.
  ///
  /// Never throws: offline use keeps the cached list.
  Future<void> refreshFriendCheckins() async {
    if (_friends.isEmpty) {
      return;
    }
    try {
      final since = DateTime.now().toUtc().subtract(worldWindow);
      final fetched = await _service.fetchCheckins(
        since: since,
        authors: List<String>.of(_friends),
        limit: friendCheckinsLimit,
      );
      _merge(_friendCheckins, fetched, limit: friendCheckinsLimit);
      _notify();
    } on NostrException {
      // Offline — keep the cache.
    }
  }

  /// Known kind 0 profiles keyed by hex pubkey.
  Map<String, NostrProfile> get profiles =>
      Map<String, NostrProfile>.unmodifiable(_profiles);

  /// Profile of [pubkey], or `null` when metadata was not fetched yet.
  NostrProfile? profileOf(String pubkey) => _profiles[pubkey.toLowerCase()];

  /// Fetches kind 0 metadata for friends, myself and (capped) world-feed
  /// authors, so the feed cards and the author sheet show names and avatars.
  Future<void> refreshProfiles() async {
    final wanted = <String>[..._friends];
    final me = pubkeyHex;
    if (me != null) {
      wanted.add(me);
    }
    var extra = 0;
    for (final checkin in _worldCheckins) {
      if (extra >= feedProfileLimit) {
        break;
      }
      final key = checkin.pubkey.trim().toLowerCase();
      if (!_profiles.containsKey(key) && !wanted.contains(key)) {
        wanted.add(key);
        extra++;
      }
    }
    if (wanted.isEmpty) {
      return;
    }
    try {
      final fetched = await _service.fetchProfiles(wanted);
      _profileFetchAttempted.addAll(wanted);
      if (fetched.isEmpty) {
        return;
      }
      _profiles.addAll(fetched);
      await _persistProfiles();
      _notify();
    } on NostrException {
      // Offline — keep the cache.
    }
  }

  /// Fetches the kind 0 metadata of one author (once per session).
  ///
  /// Returns the cached profile immediately when present; `null` while the
  /// fetch runs (the UI rebuilds when the metadata arrives).
  Future<NostrProfile?> ensureProfile(String pubkey) async {
    final key = pubkey.trim().toLowerCase();
    if (!NostrService.isValidPubkey(key)) {
      return null;
    }
    final cached = _profiles[key];
    if (cached != null) {
      return cached;
    }
    if (!_profileFetchAttempted.add(key)) {
      return null;
    }
    try {
      final fetched = await _service.fetchProfiles(<String>[key]);
      final profile = fetched[key];
      if (profile != null) {
        _profiles[key] = profile;
        await _persistProfiles();
        _notify();
      }
      return profile;
    } on NostrException {
      // Allow another attempt after a network failure.
      _profileFetchAttempted.remove(key);
      return null;
    }
  }

  /// Publishes my kind 0 metadata and caches it locally.
  Future<NostrProfile> publishProfile({
    required String name,
    String about = '',
    String picture = '',
  }) async {
    final profile = await _service.publishProfile(
      name: name,
      about: about,
      picture: picture,
    );
    _profiles[profile.pubkey] = profile;
    await _persistProfiles();
    _notify();
    return profile;
  }

  // ---------------------------------------------------------------------
  // Direct messages (NIP-04)
  // ---------------------------------------------------------------------

  /// All decrypted direct messages, oldest first.
  List<DmMessage> get dms => List<DmMessage>.unmodifiable(_dms);

  /// Messages with [pubkey] (either direction), oldest first.
  List<DmMessage> conversationWith(String pubkey) {
    final key = pubkey.trim().toLowerCase();
    final list = _dms
        .where((dm) => dm.senderPubkey == key || dm.recipientPubkey == key)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  /// Conversations, newest first, with the unread count per partner.
  List<DmConversation> get dmConversations {
    final me = pubkeyHex?.toLowerCase();
    if (me == null) {
      return const <DmConversation>[];
    }
    final grouped = <String, List<DmMessage>>{};
    for (final dm in _dms) {
      grouped.putIfAbsent(dm.counterparty(me), () => <DmMessage>[]).add(dm);
    }
    final conversations = <DmConversation>[
      for (final entry in grouped.entries)
        DmConversation(
          pubkey: entry.key,
          messages: entry.value
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
          unread: _unreadCount(entry.key, entry.value),
        ),
    ];
    conversations.sort((a, b) => b.last.createdAt.compareTo(a.last.createdAt));
    return conversations;
  }

  /// Total number of unread incoming messages (feed badge).
  int get unreadDmCount {
    var total = 0;
    for (final conversation in dmConversations) {
      total += conversation.unread;
    }
    return total;
  }

  /// Fetches recent direct messages from the relays.
  ///
  /// Never throws: offline use keeps the cached conversations.
  Future<void> refreshDms() async {
    if (!hasIdentity) {
      return;
    }
    try {
      final fetched = await _service.fetchDms(limit: dmFetchLimit);
      if (fetched.isNotEmpty) {
        _mergeDms(fetched);
        _initDmReadIfNeeded();
        await _persistDms();
        _notify();
      }
    } on NostrException {
      // Offline — keep the cache.
    }
    unawaited(_ensureDmProfiles());
  }

  /// Fetches kind 0 metadata for conversation partners we have no profile for.
  ///
  /// Runs after [refreshDms] and on live messages, so the conversation list
  /// never triggers network calls from `build()`.
  Future<void> _ensureDmProfiles() async {
    final wanted = <String>[];
    for (final conversation in dmConversations) {
      final key = conversation.pubkey;
      if (!_profiles.containsKey(key) &&
          !_profileFetchAttempted.contains(key)) {
        wanted.add(key);
      }
    }
    if (wanted.isEmpty) {
      return;
    }
    _profileFetchAttempted.addAll(wanted);
    try {
      final fetched = await _service.fetchProfiles(wanted);
      if (fetched.isEmpty) {
        return;
      }
      _profiles.addAll(fetched);
      await _persistProfiles();
      _notify();
    } on NostrException {
      // Offline — allow another attempt on the next refresh.
      _profileFetchAttempted.removeAll(wanted);
    }
  }

  /// Publishes an encrypted message to [recipientPubkey].
  Future<DmMessage> sendDm({
    required String recipientPubkey,
    required String text,
  }) async {
    final dm = await _service.publishDm(
      recipientPubkey: recipientPubkey,
      text: text,
    );
    _mergeDms(<DmMessage>[dm]);
    await _persistDms();
    _notify();
    unawaited(_ensureDmProfiles());
    return dm;
  }

  /// Starts (or restarts) the live direct-message subscription.
  void startDmLiveUpdates() {
    if (!hasIdentity) {
      return;
    }
    _dmSub?.cancel();
    _dmSub = _service.subscribeDms().listen(
      (dm) {
        _mergeDms(<DmMessage>[dm]);
        unawaited(_persistDms());
        _notify();
        unawaited(_ensureDmProfiles());
      },
      onError: (Object _) {
        // A dropped relay must not kill the UI.
      },
      cancelOnError: false,
    );
  }

  /// Marks the conversation with [pubkey] as read up to its newest message.
  void markConversationRead(String pubkey) {
    final key = pubkey.trim().toLowerCase();
    var newest = _dmLastRead[key] ?? 0;
    for (final dm in _dms) {
      if (dm.senderPubkey != key) {
        continue;
      }
      final stamp = dm.createdAt.millisecondsSinceEpoch;
      if (stamp > newest) {
        newest = stamp;
      }
    }
    if (newest == (_dmLastRead[key] ?? 0)) {
      return;
    }
    _dmLastRead[key] = newest;
    unawaited(_persistDmLastRead());
    _notify();
  }

  // ---------------------------------------------------------------------
  // Map focus (R4)
  // ---------------------------------------------------------------------

  /// Pending one-shot map focus request, or `null`.
  MapFocusRequest? get mapFocusRequest => _mapFocusRequest;

  /// Asks the map to centre on [point]; the shell switches to the map tab.
  void requestMapFocus(GeoPoint point) {
    _mapFocusCounter++;
    _mapFocusRequest = MapFocusRequest(point: point, id: _mapFocusCounter);
    _notify();
  }

  /// Consumes the request with [id]; no notify (the map already moved).
  void clearMapFocus(int id) {
    if (_mapFocusRequest?.id != id) {
      return;
    }
    _mapFocusRequest = null;
  }

  // ---------------------------------------------------------------------
  // Live updates
  // ---------------------------------------------------------------------

  /// Starts (or restarts) the live check-in subscription.
  void startLiveUpdates() {
    _liveSub?.cancel();
    _liveSub = _service
        .subscribeCheckins(since: DateTime.now().toUtc().subtract(worldWindow))
        .listen(
          (checkin) {
            _merge(_worldCheckins, <CheckinEvent>[checkin], limit: worldLimit);
            final author = checkin.pubkey.trim().toLowerCase();
            if (_friends.contains(author)) {
              _merge(_friendCheckins, <CheckinEvent>[
                checkin,
              ], limit: friendCheckinsLimit);
            }
            if (author == (pubkeyHex ?? '').toLowerCase()) {
              _merge(_myCheckins, <CheckinEvent>[
                checkin,
              ], limit: myCheckinsLimit);
              unawaited(_persistMyCheckins());
            }
            _notify();
          },
          onError: (Object _) {
            // A dropped relay must not kill the UI.
          },
          cancelOnError: false,
        );
  }

  /// Stops the live subscription.
  void stopLiveUpdates() {
    _liveSub?.cancel();
    _liveSub = null;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  Future<void> _syncQuietly() async {
    _syncInProgress = true;
    _notify();
    try {
      await _service.connect();
      await refresh();
    } on Object {
      // Offline boot is a normal situation.
    } finally {
      _syncInProgress = false;
      _notify();
    }
  }

  /// Reads the coarse position and encodes it as a geohash.
  ///
  /// Returns `null` when the platform has no location or permission — the
  /// check-in is then published without a location.
  Future<String?> _resolveGeohash(LocationPrecision precision) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return Geohash.encode(
        position.latitude,
        position.longitude,
        precision: precision.geohashPrecision,
      );
    } on Object {
      return null;
    }
  }

  /// Merges [incoming] into [target], newest first, deduplicated by id.
  void _merge(
    List<CheckinEvent> target,
    Iterable<CheckinEvent> incoming, {
    required int limit,
  }) {
    final byId = <String, CheckinEvent>{
      for (final checkin in target) checkin.id: checkin,
      for (final checkin in incoming) checkin.id: checkin,
    };
    final merged = byId.values.toList()
      ..sort((a, b) {
        final byTime = b.createdAt.compareTo(a.createdAt);
        if (byTime != 0) {
          return byTime;
        }
        return b.id.compareTo(a.id);
      });
    if (merged.length > limit) {
      merged.removeRange(limit, merged.length);
    }
    target
      ..clear()
      ..addAll(merged);
  }

  void _restoreMyCheckins(SharedPreferences prefs) {
    final raw = prefs.getString(keyMyCheckins);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      final restored = <CheckinEvent>[];
      for (final entry in decoded) {
        if (entry is Map<String, dynamic>) {
          final checkin = CheckinEvent.fromJson(entry);
          if (checkin != null) {
            restored.add(checkin);
          }
        }
      }
      _merge(_myCheckins, restored, limit: myCheckinsLimit);
    } on FormatException {
      // Corrupted cache — start with an empty list.
    }
  }

  Future<void> _persistMyCheckins() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final payload = jsonEncode(<Map<String, dynamic>>[
      for (final c in _myCheckins) c.toJson(),
    ]);
    await prefs.setString(keyMyCheckins, payload);
  }

  void _restoreProfiles(SharedPreferences prefs) {
    final raw = prefs.getString(keyProfiles);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is Map<String, dynamic>) {
          _profiles[entry.key] = NostrProfile(
            pubkey: entry.key,
            name: value['name'] as String?,
            displayName: value['display_name'] as String?,
            about: value['about'] as String?,
            picture: value['picture'] as String?,
            nip05: value['nip05'] as String?,
          );
        }
      }
    } on FormatException {
      // Corrupted cache — start empty.
    }
  }

  Future<void> _persistProfiles() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final payload = jsonEncode(<String, Map<String, dynamic>>{
      for (final entry in _profiles.entries)
        entry.key: <String, dynamic>{
          'name': entry.value.name,
          'display_name': entry.value.displayName,
          'about': entry.value.about,
          'picture': entry.value.picture,
          'nip05': entry.value.nip05,
        },
    });
    await prefs.setString(keyProfiles, payload);
  }

  void _restoreDms(SharedPreferences prefs) {
    final raw = prefs.getString(keyDms);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final restored = <DmMessage>[];
          for (final entry in decoded) {
            if (entry is Map<String, dynamic>) {
              final message = DmMessage.fromJson(entry);
              if (message != null) {
                restored.add(message);
              }
            }
          }
          _mergeDms(restored);
        }
      } on FormatException {
        // Corrupted cache — start empty.
      }
    }
    final readRaw = prefs.getString(keyDmLastRead);
    if (readRaw != null && readRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(readRaw);
        if (decoded is Map<String, dynamic>) {
          _dmLastRead = <String, int>{
            for (final entry in decoded.entries)
              if (entry.value is num) entry.key: (entry.value as num).toInt(),
          };
        }
      } on FormatException {
        // Ignore malformed markers.
      }
    }
  }

  Future<void> _persistDms() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    final payload = jsonEncode(<Map<String, dynamic>>[
      for (final dm in _dms) dm.toJson(),
    ]);
    await prefs.setString(keyDms, payload);
  }

  Future<void> _persistDmLastRead() async {
    final prefs = _prefs;
    if (prefs == null) {
      return;
    }
    await prefs.setString(keyDmLastRead, jsonEncode(_dmLastRead));
  }

  /// Merges [incoming] direct messages, oldest first, deduplicated by id.
  void _mergeDms(Iterable<DmMessage> incoming) {
    final byId = <String, DmMessage>{
      for (final dm in _dms) dm.id: dm,
      for (final dm in incoming) dm.id: dm,
    };
    final merged = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (merged.length > dmFetchLimit) {
      merged.removeRange(0, merged.length - dmFetchLimit);
    }
    _dms
      ..clear()
      ..addAll(merged);
  }

  /// Counts unread incoming messages from [partner] in [messages].
  int _unreadCount(String partner, List<DmMessage> messages) {
    final since = _dmLastRead[partner] ?? 0;
    var count = 0;
    for (final dm in messages) {
      if (dm.senderPubkey != partner) {
        continue;
      }
      if (dm.createdAt.millisecondsSinceEpoch > since) {
        count++;
      }
    }
    return count;
  }

  /// On the very first DM sync (no stored read markers) everything that was
  /// fetched counts as seen — the badge only tracks messages arriving later.
  void _initDmReadIfNeeded() {
    if (_dmLastRead.isNotEmpty) {
      return;
    }
    final me = pubkeyHex?.toLowerCase();
    if (me == null) {
      return;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final dm in _dms) {
      if (dm.senderPubkey == me) {
        continue;
      }
      final other = dm.counterparty(me);
      final existing = _dmLastRead[other] ?? 0;
      if (now > existing) {
        _dmLastRead[other] = now;
      }
    }
    unawaited(_persistDmLastRead());
  }
}

/// One-shot request to centre the map on a point (R4 show on map).
class MapFocusRequest {
  const MapFocusRequest({required this.point, required this.id});

  /// Where to centre the camera.
  final GeoPoint point;

  /// Monotonic id, so the map handles every request exactly once.
  final int id;
}
