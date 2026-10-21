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
import '../models/emotion.dart';
import '../models/profile.dart';
import '../nostr/nostr_service.dart';
import '../social/friends.dart';

/// Coarse location granularity of a check-in (SPEC: off / area / city).
enum LocationPrecision {
  /// No location is attached to check-ins.
  off(0),

  /// Geohash precision 3 — a coarse area (~150 km).
  area(Geohash.areaPrecision),

  /// Geohash precision 5 — a city-sized cell (~5 km).
  city(Geohash.cityPrecision);

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

  /// How far back the world feed / map loads check-ins.
  static const Duration worldWindow = Duration(days: 30);

  /// Maximum number of world check-ins kept in memory.
  static const int worldLimit = 500;

  /// Maximum number of my check-ins kept in memory (and on disk).
  static const int myCheckinsLimit = 500;

  final NostrService _service;
  SharedPreferences? _prefs;

  String _language = 'cs';
  LocationPrecision _locationPrecision = LocationPrecision.off;
  final List<CheckinEvent> _myCheckins = <CheckinEvent>[];
  final List<CheckinEvent> _worldCheckins = <CheckinEvent>[];
  final Map<String, NostrProfile> _profiles = <String, NostrProfile>{};
  List<String> _friends = <String>[];
  bool _syncInProgress = false;
  bool _disposed = false;
  StreamSubscription<CheckinEvent>? _liveSub;

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
    _locationPrecision =
        LocationPrecision.fromName(prefs.getString(keyLocationPrecision));
    _friends = dedupeFriendKeys(prefs.getStringList(keyFriends) ?? const []);
    final relays = prefs.getStringList(keyRelays);
    if (relays != null && relays.isNotEmpty) {
      _service.relays = List<String>.of(relays);
    }
    _restoreMyCheckins(prefs);
    await _service.loadIdentity();
    if (autoSync) {
      unawaited(_syncQuietly());
      startLiveUpdates();
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _liveSub?.cancel();
    _liveSub = null;
    _service.dispose();
    super.dispose();
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
    _profiles.clear();
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
  List<CheckinEvent> get myCheckins => List<CheckinEvent>.unmodifiable(_myCheckins);

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

  /// Fetches my check-ins, the world window and friend profiles from relays.
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
    if (includeProfiles && _friends.isNotEmpty) {
      await refreshProfiles();
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
  /// The returned [AddFriendOutcome] tells the UI what happened.
  AddFriendOutcome addFriend(String input) {
    final result = addFriendKey(_friends, input);
    if (result.outcome == AddFriendOutcome.added) {
      _friends = result.keys;
      unawaited(_prefs?.setStringList(keyFriends, _friends));
      unawaited(refreshProfiles());
      _notify();
    }
    return result.outcome;
  }

  /// Removes a friend by `npub...` or hex key. Returns `true` when removed.
  bool removeFriend(String input) {
    final updated = removeFriendKey(_friends, input);
    if (updated.length == _friends.length) {
      return false;
    }
    _friends = updated;
    unawaited(_prefs?.setStringList(keyFriends, _friends));
    _notify();
    return true;
  }

  /// Known kind 0 profiles keyed by hex pubkey.
  Map<String, NostrProfile> get profiles =>
      Map<String, NostrProfile>.unmodifiable(_profiles);

  /// Profile of [pubkey], or `null` when metadata was not fetched yet.
  NostrProfile? profileOf(String pubkey) => _profiles[pubkey.toLowerCase()];

  /// Fetches kind 0 metadata for friends (and myself).
  Future<void> refreshProfiles() async {
    final wanted = <String>[..._friends];
    final me = pubkeyHex;
    if (me != null) {
      wanted.add(me);
    }
    if (wanted.isEmpty) {
      return;
    }
    try {
      final fetched = await _service.fetchProfiles(wanted);
      if (fetched.isEmpty) {
        return;
      }
      _profiles.addAll(fetched);
      _notify();
    } on NostrException {
      // Offline — keep the cache.
    }
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
        if (checkin.pubkey.toLowerCase() == (pubkeyHex ?? '').toLowerCase()) {
          _merge(_myCheckins, <CheckinEvent>[checkin], limit: myCheckinsLimit);
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
    final payload = jsonEncode(
      <Map<String, dynamic>>[for (final c in _myCheckins) c.toJson()],
    );
    await prefs.setString(keyMyCheckins, payload);
  }
}
