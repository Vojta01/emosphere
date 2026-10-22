// EmoSphere Nostr layer.
//
// Wraps the dart_nostr primitives (keys, events, NIP-19 bech32) and talks to
// relays directly over WebSocket, which keeps the protocol handling explicit
// and testable (deduplication, EOSE, timeouts, NIP-09 deletions).
//
// Public surface used by the other EmoSphere cards:
//   * identity:   generateIdentity / loadIdentity / saveIdentity /
//                 importIdentity / clearIdentity / keyPairs / npub
//   * relay:      connect / disconnect / relays / isConnected
//   * events:     publishCheckin / subscribeCheckins / fetchCheckins /
//                 fetchProfiles / deleteMyCheckins
//   * statics:    defaultRelays / npubOf / hexFromNpub / nsecOf / isValidPubkey

import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/checkin.dart';
import '../models/dm.dart';
import '../models/emotion.dart';
import '../models/profile.dart';
import 'nip04.dart';

/// Creates a WebSocket channel for [uri]. Injectable for tests.
typedef RelayChannelFactory = WebSocketChannel Function(Uri uri);

/// Error raised by the Nostr layer.
class NostrException implements Exception {
  NostrException(this.message);

  /// Human readable reason.
  final String message;

  @override
  String toString() => 'NostrException: $message';
}

/// Nostr relay client for EmoSphere.
class NostrService {
  NostrService({
    List<String>? relays,
    RelayChannelFactory? channelFactory,
    FlutterSecureStorage? secureStorage,
    this.readTimeout = const Duration(seconds: 8),
    this.publishTimeout = const Duration(seconds: 10),
  }) : relays = List<String>.of(relays ?? defaultRelays),
       _channelFactory = channelFactory ?? _defaultChannelFactory,
       _storage = secureStorage ?? const FlutterSecureStorage();

  /// Default relays from the SPEC (the user can edit them in Settings).
  static const List<String> defaultRelays = <String>[
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.primal.net',
    'wss://relay.nostr.band',
  ];

  static const String storageKeyPrivateKey = 'emosphere_private_key';

  static final RegExp _hex64 = RegExp(r'^[0-9a-f]{64}$');

  /// Nostr kind for NIP-04 direct messages.
  static const int dmKind = 4;

  static final Nostr _nostr = Nostr.instance..disableLogs();

  static WebSocketChannel _defaultChannelFactory(Uri uri) =>
      WebSocketChannel.connect(uri);

  final FlutterSecureStorage _storage;
  final RelayChannelFactory _channelFactory;

  /// Timeout for connect and one-shot queries.
  final Duration readTimeout;

  /// Timeout for waiting on relay `OK` answers.
  final Duration publishTimeout;

  /// Relay URLs currently configured.
  List<String> relays;

  final Map<String, _RelayConnection> _connections = {};

  NostrKeyPairs? _keyPairs;
  Future<void>? _connecting;
  int _subCounter = 0;

  /// Ids whose BIP-340 signature was verified in this session.
  ///
  /// The id is a SHA-256 of the serialized fields, so an id in this set
  /// guarantees the signature was checked for exactly this payload.
  final Set<String> _verifiedIds = <String>{};

  /// Cap for [_verifiedIds]; the cache is dropped wholesale when it fills.
  static const int _verifiedIdCacheCap = 5000;

  // ---------------------------------------------------------------------
  // Identity
  // ---------------------------------------------------------------------

  /// The active identity, or `null` when no key was generated/imported yet.
  NostrKeyPairs? get keyPairs => _keyPairs;

  /// Hex public key of the active identity.
  String? get pubkeyHex => _keyPairs?.public;

  /// `npub...` of the active identity.
  String? get npub => _keyPairs == null ? null : npubOf(_keyPairs!.public);

  /// `nsec...` of the active identity (for the backup screen).
  String? get nsec => _keyPairs == null ? null : nsecOf(_keyPairs!.private);

  /// Whether an identity is available.
  bool get hasIdentity => _keyPairs != null;

  /// Generates a new key pair and persists it in secure storage.
  Future<NostrKeyPairs> generateIdentity() async {
    final keys = NostrKeyPairs.generate();
    await saveIdentity(keys);
    return keys;
  }

  /// Persists [keys] in secure storage and makes them the active identity.
  Future<void> saveIdentity(NostrKeyPairs keys) async {
    _keyPairs = keys;
    await _storage.write(key: storageKeyPrivateKey, value: keys.private);
  }

  /// Loads the identity from secure storage. Returns `null` when absent.
  Future<NostrKeyPairs?> loadIdentity() async {
    String? stored;
    try {
      stored = await _storage.read(key: storageKeyPrivateKey);
    } on Exception {
      stored = null;
    }
    if (stored == null || !isValidPrivateKey(stored)) {
      return null;
    }
    _keyPairs = NostrKeyPairs(private: stored.toLowerCase());
    return _keyPairs;
  }

  /// Imports an existing identity from a `nsec...` or 64-char hex private key.
  Future<NostrKeyPairs> importIdentity(String nsecOrHex) async {
    final hex = normalizePrivateKey(nsecOrHex);
    NostrKeyPairs keys;
    try {
      keys = NostrKeyPairs(private: hex);
      // Force public key derivation so invalid scalars fail here.
      final pubkey = keys.public;
      if (!isValidPubkey(pubkey)) {
        throw NostrException('Invalid private key.');
      }
    } on NostrException {
      rethrow;
    } on Object {
      throw NostrException('Invalid private key.');
    }
    await saveIdentity(keys);
    return keys;
  }

  /// Removes the identity from secure storage.
  Future<void> clearIdentity() async {
    _keyPairs = null;
    try {
      await _storage.delete(key: storageKeyPrivateKey);
    } on Exception {
      // Nothing to delete.
    }
  }

  /// Validates a 64-char hex private key.
  static bool isValidPrivateKey(String value) => _hex64.hasMatch(value);

  /// Validates a 64-char hex public key.
  static bool isValidPubkey(String value) => _hex64.hasMatch(value);

  /// Converts `nsec...`/hex input into a lowercase hex private key.
  static String normalizePrivateKey(String value) {
    final input = value.trim();
    if (input.startsWith('nsec1')) {
      try {
        return _nostr.bech32.decodeNsecKeyToPrivateKey(input).toLowerCase();
      } on Object {
        throw NostrException('Invalid nsec key.');
      }
    }
    final lower = input.toLowerCase();
    if (isValidPrivateKey(lower)) {
      return lower;
    }
    throw NostrException('Invalid private key.');
  }

  /// Encodes a hex public key as `npub...`.
  static String npubOf(String pubkeyHex) =>
      _nostr.bech32.encodePublicKeyToNpub(pubkeyHex.toLowerCase());

  /// Encodes a hex private key as `nsec...`.
  static String nsecOf(String privateKeyHex) =>
      _nostr.bech32.encodePrivateKeyToNsec(privateKeyHex.toLowerCase());

  /// Decodes an `npub...` (or returns a hex key unchanged) into hex.
  static String hexFromNpub(String value) {
    final input = value.trim();
    if (input.startsWith('npub1')) {
      try {
        return _nostr.bech32.decodeNpubKeyToPublicKey(input).toLowerCase();
      } on Object {
        throw NostrException('Invalid npub key.');
      }
    }
    final lower = input.toLowerCase();
    if (isValidPubkey(lower)) {
      return lower;
    }
    throw NostrException('Invalid npub key.');
  }

  /// `true` when [value] is a syntactically valid `npub...` or hex pubkey.
  static bool looksLikePubkey(String value) {
    final input = value.trim();
    if (input.startsWith('npub1')) {
      try {
        decodeNpub(input);
        return true;
      } on NostrException {
        return false;
      }
    }
    return isValidPubkey(input.toLowerCase());
  }

  /// Decodes `npub...` without the "hex passthrough" behaviour.
  static String decodeNpub(String npubKey) {
    if (!npubKey.startsWith('npub1') || npubKey.length < 60) {
      throw NostrException('Invalid npub key.');
    }
    try {
      return _nostr.bech32.decodeNpubKeyToPublicKey(npubKey).toLowerCase();
    } on Object {
      throw NostrException('Invalid npub key.');
    }
  }

  // ---------------------------------------------------------------------
  // Relay connection
  // ---------------------------------------------------------------------

  /// `true` when at least one relay connection is alive.
  bool get isConnected => _liveRelays.isNotEmpty;

  /// URLs of the currently alive relay connections.
  List<String> get connectedRelays =>
      _liveRelays.map((connection) => connection.url).toList();

  List<_RelayConnection> get _liveRelays =>
      _connections.values.where((connection) => !connection.closed).toList();

  /// Connects to [relayUrls] (or the configured [relays] when omitted).
  ///
  /// Unreachable relays are skipped — the call succeeds as long as the
  /// connection attempt itself did not throw.
  Future<void> connect({List<String>? relayUrls}) {
    final pending = _connecting;
    if (pending != null) {
      return pending;
    }
    final future = _doConnect(relayUrls);
    _connecting = future;
    return future.whenComplete(() {
      if (identical(_connecting, future)) {
        _connecting = null;
      }
    });
  }

  Future<void> _doConnect(List<String>? relayUrls) async {
    if (relayUrls != null && relayUrls.isNotEmpty) {
      relays = List<String>.of(relayUrls);
    }
    final wanted = relays.toSet();
    for (final url in _connections.keys.toList()) {
      if (!wanted.contains(url)) {
        await _connections.remove(url)?.close();
      }
    }
    for (final url in relays) {
      if (_connections.containsKey(url)) {
        continue;
      }
      _RelayConnection connection;
      try {
        connection = _RelayConnection(url, _channelFactory(Uri.parse(url)));
      } on Object {
        continue;
      }
      _connections[url] = connection;
      await connection.ready.timeout(readTimeout, onTimeout: () {});
      if (connection.lastError != null || connection.closed) {
        await _connections.remove(url)?.close();
      }
    }
  }

  /// Closes all relay connections.
  Future<void> disconnect() async {
    for (final connection in _connections.values.toList()) {
      await connection.close();
    }
    _connections.clear();
  }

  /// Updates the relay list and reconnects.
  Future<void> setRelays(List<String> relayUrls) async {
    final cleaned = relayUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList();
    relays = cleaned.isEmpty ? List<String>.of(defaultRelays) : cleaned;
    await disconnect();
    await connect();
  }

  Future<void> _ensureConnected() async {
    if (_liveRelays.isNotEmpty) {
      return;
    }
    await connect();
    if (_liveRelays.isEmpty) {
      throw NostrException('Could not connect to any relay.');
    }
  }

  // ---------------------------------------------------------------------
  // Check-ins
  // ---------------------------------------------------------------------

  /// Builds the REQ filter for EmoSphere check-in events.
  static Map<String, dynamic> checkinFilter({
    DateTime? since,
    List<String>? authors,
    int? limit,
  }) {
    return <String, dynamic>{
      'kinds': <int>[CheckinEvent.kindValue],
      '#t': <String>[CheckinEvent.hashtag],
      if (since != null) 'since': since.toUtc().millisecondsSinceEpoch ~/ 1000,
      if (authors != null && authors.isNotEmpty) 'authors': authors,
      if (limit != null && limit > 0) 'limit': limit,
    };
  }

  /// Publishes one check-in and returns the stored event.
  Future<CheckinEvent> publishCheckin({
    required Emotion emotion,
    required int intensity,
    String note = '',
    String? geohash,
    DateTime? createdAt,
  }) async {
    final keys = _keyPairs;
    if (keys == null) {
      throw NostrException('No identity available.');
    }
    final event = CheckinEvent.buildEvent(
      emotion: emotion,
      intensity: intensity,
      note: note,
      geohash: geohash,
      keyPairs: keys,
      createdAt: createdAt,
    );
    await publishEvent(event);
    final stored = CheckinEvent.fromNostrEvent(event);
    if (stored == null) {
      throw NostrException('Could not rebuild the published check-in.');
    }
    return stored;
  }

  /// Publishes kind 0 metadata for the active identity.
  Future<NostrProfile> publishProfile({
    required String name,
    String about = '',
    String picture = '',
  }) async {
    final keys = _keyPairs;
    if (keys == null) {
      throw NostrException('No identity available.');
    }
    final cleanName = name.trim();
    final cleanAbout = about.trim();
    final cleanPicture = picture.trim();
    final content = jsonEncode(<String, dynamic>{
      if (cleanName.isNotEmpty) 'name': cleanName,
      if (cleanAbout.isNotEmpty) 'about': cleanAbout,
      if (cleanPicture.isNotEmpty) 'picture': cleanPicture,
    });
    final event = NostrEvent.fromPartialData(
      kind: 0,
      content: content,
      keyPairs: keys,
      tags: const <List<String>>[],
      createdAt: DateTime.now().toUtc(),
    );
    await publishEvent(event);
    return NostrProfile(
      pubkey: keys.public,
      name: cleanName.isEmpty ? null : cleanName,
      about: cleanAbout.isEmpty ? null : cleanAbout,
      picture: cleanPicture.isEmpty ? null : cleanPicture,
      updatedAt: event.createdAt?.toUtc(),
    );
  }

  /// Encrypts and publishes a NIP-04 direct message (kind 4).
  Future<DmMessage> publishDm({
    required String recipientPubkey,
    required String text,
  }) async {
    final keys = _keyPairs;
    if (keys == null) {
      throw NostrException('No identity available.');
    }
    final recipient = recipientPubkey.trim().toLowerCase();
    if (!isValidPubkey(recipient)) {
      throw NostrException('Invalid recipient pubkey.');
    }
    final String content;
    try {
      content = Nip04.encrypt(
        senderPrivateHex: keys.private,
        recipientPubkeyHex: recipient,
        plaintext: text,
      );
    } on FormatException {
      throw NostrException('Invalid recipient pubkey.');
    }
    final event = NostrEvent.fromPartialData(
      kind: dmKind,
      content: content,
      keyPairs: keys,
      tags: <List<String>>[
        <String>['p', recipient],
      ],
      createdAt: DateTime.now().toUtc(),
    );
    await publishEvent(event);
    return DmMessage(
      id: event.id!,
      senderPubkey: keys.public,
      recipientPubkey: recipient,
      text: text,
      createdAt: (event.createdAt ?? DateTime.now()).toUtc(),
    );
  }

  /// Signs and publishes a raw event, waiting for a relay `OK`.
  Future<void> publishEvent(NostrEvent event, {Duration? timeout}) async {
    final id = event.id;
    if (id == null) {
      throw NostrException('Event has no id.');
    }
    await _ensureConnected();
    final payload = jsonEncode(<dynamic>['EVENT', event.toMap()]);
    final waiters = <Future<bool>>[];
    for (final connection in _liveRelays) {
      try {
        connection.send(payload);
        waiters.add(connection.waitForOk(id, timeout ?? publishTimeout));
      } on Object {
        // Ignore a single broken connection.
      }
    }
    if (waiters.isEmpty) {
      throw NostrException('Could not connect to any relay.');
    }
    final results = await Future.wait(waiters);
    if (!results.any((accepted) => accepted)) {
      throw NostrException('All relays rejected the event.');
    }
  }

  /// Live stream of check-ins matching [since]/[authors].
  ///
  /// Events are deduplicated by id, so the same check-in arriving from several
  /// relays is emitted once. The stream keeps running until cancelled.
  Stream<CheckinEvent> subscribeCheckins({
    DateTime? since,
    List<String>? authors,
    int? limit,
  }) async* {
    await _ensureConnected();
    final handle = _openSubscription(
      checkinFilter(since: since, authors: authors, limit: limit),
    );
    try {
      await for (final event in handle.controller.stream) {
        final checkin = _toCheckin(event);
        if (checkin != null) {
          yield checkin;
        }
      }
    } finally {
      await handle.close();
    }
  }

  /// One-shot query: collects check-ins until every relay sent `EOSE`
  /// (or [timeout] elapsed) and returns them newest first.
  Future<List<CheckinEvent>> fetchCheckins({
    DateTime? since,
    List<String>? authors,
    int? limit,
    Duration? timeout,
  }) async {
    await _ensureConnected();
    final handle = _openSubscription(
      checkinFilter(since: since, authors: authors, limit: limit),
      autoCloseOnEose: true,
    );
    final timer = Timer(timeout ?? readTimeout, handle.close);
    final byId = <String, CheckinEvent>{};
    try {
      await for (final event in handle.controller.stream) {
        final checkin = _toCheckin(event);
        if (checkin != null) {
          byId[checkin.id] = checkin;
        }
      }
    } finally {
      timer.cancel();
      await handle.close();
    }
    final result = byId.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  /// Convenience wrapper for the signed-in user's own check-ins.
  Future<List<CheckinEvent>> fetchMyCheckins({int limit = 200}) {
    final keys = _keyPairs;
    if (keys == null) {
      return Future<List<CheckinEvent>>.value(<CheckinEvent>[]);
    }
    return fetchCheckins(authors: <String>[keys.public], limit: limit);
  }

  /// Fetches kind 0 profiles for [pubkeys], newest metadata per author.
  Future<Map<String, NostrProfile>> fetchProfiles(
    Iterable<String> pubkeys, {
    Duration? timeout,
  }) async {
    final authors = pubkeys
        .map((value) => value.trim().toLowerCase())
        .where(isValidPubkey)
        .toSet()
        .toList();
    if (authors.isEmpty) {
      return <String, NostrProfile>{};
    }
    await _ensureConnected();
    final handle = _openSubscription(<String, dynamic>{
      'kinds': <int>[0],
      'authors': authors,
      'limit': authors.length,
    }, autoCloseOnEose: true);
    final timer = Timer(timeout ?? readTimeout, handle.close);
    final profiles = <String, NostrProfile>{};
    try {
      await for (final event in handle.controller.stream) {
        final profile = NostrProfile.fromEvent(event);
        if (profile == null) {
          continue;
        }
        final existing = profiles[profile.pubkey];
        final isNewer =
            existing == null ||
            (profile.updatedAt != null &&
                (existing.updatedAt == null ||
                    profile.updatedAt!.isAfter(existing.updatedAt!)));
        if (isNewer) {
          profiles[profile.pubkey] = profile;
        }
      }
    } on Object {
      // Malformed metadata must not break the whole fetch.
    } finally {
      timer.cancel();
      await handle.close();
    }
    return profiles;
  }

  /// Fetches recent NIP-04 messages (incoming + outgoing), oldest first.
  Future<List<DmMessage>> fetchDms({int limit = 300, Duration? timeout}) async {
    final keys = _keyPairs;
    if (keys == null) {
      return <DmMessage>[];
    }
    await _ensureConnected();
    final byId = <String, DmMessage>{};
    Future<void> collect(Map<String, dynamic> filter) async {
      final handle = _openSubscription(filter, autoCloseOnEose: true);
      final timer = Timer(timeout ?? readTimeout, handle.close);
      try {
        await for (final event in handle.controller.stream) {
          final dm = _toDm(event);
          if (dm != null) {
            byId[dm.id] = dm;
          }
        }
      } on Object {
        // Malformed payloads must not break the whole fetch.
      } finally {
        timer.cancel();
        await handle.close();
      }
    }

    // Incoming and outgoing are independent — query both in parallel.
    await Future.wait(<Future<void>>[
      collect(<String, dynamic>{
        'kinds': <int>[dmKind],
        '#p': <String>[keys.public],
        'limit': limit,
      }),
      collect(<String, dynamic>{
        'kinds': <int>[dmKind],
        'authors': <String>[keys.public],
        'limit': limit,
      }),
    ]);
    final result = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
  }

  /// Live stream of my NIP-04 messages (incoming and outgoing).
  Stream<DmMessage> subscribeDms() async* {
    final keys = _keyPairs;
    if (keys == null) {
      return;
    }
    await _ensureConnected();
    final incoming = _openSubscription(<String, dynamic>{
      'kinds': <int>[dmKind],
      '#p': <String>[keys.public],
    });
    final outgoing = _openSubscription(<String, dynamic>{
      'kinds': <int>[dmKind],
      'authors': <String>[keys.public],
    });
    final controller = StreamController<DmMessage>();
    var done = 0;
    void noteDone() {
      done++;
      if (done >= 2 && !controller.isClosed) {
        controller.close();
      }
    }

    void forward(NostrEvent event) {
      final dm = _toDm(event);
      if (dm != null && !controller.isClosed) {
        controller.add(dm);
      }
    }

    final incomingSub = incoming.controller.stream.listen(
      forward,
      onDone: noteDone,
      onError: (Object _) {},
    );
    final outgoingSub = outgoing.controller.stream.listen(
      forward,
      onDone: noteDone,
      onError: (Object _) {},
    );
    try {
      yield* controller.stream;
    } finally {
      await incomingSub.cancel();
      await outgoingSub.cancel();
      await incoming.close();
      await outgoing.close();
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  /// Publishes kind 5 deletions (NIP-09) for [checkins] (or all stored ones).
  ///
  /// Returns the number of deleted events referenced.
  Future<int> deleteMyCheckins({List<CheckinEvent>? checkins}) async {
    final keys = _keyPairs;
    if (keys == null) {
      throw NostrException('No identity available.');
    }
    final targets = checkins ?? await fetchMyCheckins();
    if (targets.isEmpty) {
      return 0;
    }
    const chunkSize = 100;
    var deleted = 0;
    for (var start = 0; start < targets.length; start += chunkSize) {
      final end = start + chunkSize > targets.length
          ? targets.length
          : start + chunkSize;
      final ids = targets.sublist(start, end).map((c) => c.id).toList();
      final deletion = NostrEvent.deleteEvent(
        keyPairs: keys,
        eventIdsToBeDeleted: ids,
        reasonOfDeletion: 'EmoSphere: user deleted check-ins',
      );
      await publishEvent(deletion);
      deleted += ids.length;
    }
    return deleted;
  }

  // ---------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------

  CheckinEvent? _toCheckin(NostrEvent event) {
    try {
      return CheckinEvent.fromNostrEvent(event);
    } on Object {
      return null;
    }
  }

  /// Parses + decrypts one kind 4 event for the active identity.
  DmMessage? _toDm(NostrEvent event) {
    final keys = _keyPairs;
    if (keys == null || event.kind != dmKind) {
      return null;
    }
    final id = event.id;
    if (id == null) {
      return null;
    }
    final me = keys.public.toLowerCase();
    final sender = event.pubkey.trim().toLowerCase();
    var recipient = '';
    for (final tag in event.tags ?? const <List<String>>[]) {
      if (tag.length >= 2 && tag[0] == 'p') {
        recipient = tag[1].trim().toLowerCase();
        break;
      }
    }
    if (recipient.isEmpty) {
      return null;
    }
    if (sender != me && recipient != me) {
      return null;
    }
    final other = sender == me ? recipient : sender;
    final text = Nip04.decrypt(
      recipientPrivateHex: keys.private,
      senderPubkeyHex: other,
      content: event.content ?? '',
    );
    if (text == null) {
      return null;
    }
    return DmMessage(
      id: id,
      senderPubkey: sender,
      recipientPubkey: recipient,
      text: text,
      createdAt: (event.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .toUtc(),
    );
  }

  _SubHandle _openSubscription(
    Map<String, dynamic> filter, {
    bool autoCloseOnEose = false,
  }) {
    final id = 'emosphere-${_subCounter++}';
    final controller = StreamController<NostrEvent>.broadcast();
    final handle = _SubHandle(
      id: id,
      controller: controller,
      relayCount: _liveRelays.length,
      autoCloseOnEose: autoCloseOnEose,
    );
    final request = jsonEncode(<dynamic>['REQ', id, filter]);
    for (final connection in _liveRelays) {
      connection.handlers[id] = (type, message) {
        if (handle.closed) {
          return;
        }
        switch (type) {
          case 'EVENT':
            final event = _parseEvent(message);
            if (event != null &&
                handle.addIfNew(event) &&
                !controller.isClosed) {
              controller.add(event);
            }
          case 'EOSE':
            handle.noteEose(connection.url);
          case 'CLOSED':
            handle.noteEose(connection.url);
        }
      };
      connection.send(request);
    }
    handle.onClose = () async {
      for (final connection in _liveRelays) {
        connection.handlers.remove(id);
        connection.send(jsonEncode(<dynamic>['CLOSE', id]));
      }
      if (!controller.isClosed) {
        controller.close();
      }
    };
    controller.onCancel = handle.close;
    return handle;
  }

  NostrEvent? _parseEvent(List<dynamic> message) {
    if (message.length < 3) {
      return null;
    }
    try {
      final event = NostrEvent.fromDecodedMessage(message);
      if (!_isAuthentic(event)) {
        return null;
      }
      return event;
    } on Object {
      // Malformed payload from a relay — ignore it.
      return null;
    }
  }

  /// True when [event] passes the authenticity checks.
  ///
  /// The id is always recomputed from the serialized fields (a cheap SHA-256),
  /// so a compromised relay can neither tamper with fields nor replay a
  /// signature under a different body. The BIP-340 signature check costs
  /// milliseconds per event, so it is cached per id — and since the id is a
  /// hash of the fields, a cached id means exactly this payload was checked.
  bool _isAuthentic(NostrEvent event) {
    final id = event.id;
    final sig = event.sig;
    final kind = event.kind;
    final createdAt = event.createdAt;
    if (id == null || sig == null || kind == null || createdAt == null) {
      return false;
    }
    final expectedId = NostrEvent.getEventId(
      kind: kind,
      content: event.content ?? '',
      createdAt: createdAt,
      tags: event.tags ?? const <List<String>>[],
      pubkey: event.pubkey,
    );
    if (expectedId != id) {
      return false;
    }
    if (_verifiedIds.contains(id)) {
      return true;
    }
    if (!NostrKeyPairs.verify(event.pubkey, id, sig)) {
      return false;
    }
    if (_verifiedIds.length >= _verifiedIdCacheCap) {
      _verifiedIds.clear();
    }
    _verifiedIds.add(id);
    return true;
  }

  /// Closes all relay connections and subscriptions.
  Future<void> dispose() => disconnect();
}

/// One live relay WebSocket connection.
class _RelayConnection {
  _RelayConnection(this.url, this._channel) {
    _ready = _channel.ready
        .then((_) {
          if (!opened.isCompleted) {
            opened.complete();
          }
        })
        .catchError((Object error) {
          lastError = error;
          if (!opened.isCompleted) {
            opened.complete();
          }
        });
    _subscription = _channel.stream.listen(
      _handleMessage,
      onError: (Object error) {
        lastError = error;
      },
      onDone: () {
        closed = true;
      },
      cancelOnError: false,
    );
  }

  final String url;
  final WebSocketChannel _channel;
  late final Future<void> _ready;
  late final StreamSubscription<dynamic> _subscription;

  /// Subscription handlers keyed by subscription id.
  final Map<String, void Function(String type, List<dynamic> message)>
  handlers = {};

  final Map<String, Completer<bool>> _okWaiters = {};

  /// Completes when the socket opened or failed (never errors).
  final Completer<void> opened = Completer<void>();

  bool closed = false;
  Object? lastError;

  Future<void> get ready => _ready;

  void _handleMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    List<dynamic> message;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return;
      }
      message = decoded;
    } on FormatException {
      return;
    }
    if (message.isEmpty) {
      return;
    }
    final type = message[0];
    if (type is! String) {
      return;
    }
    if (type == 'OK') {
      final id = message.length > 1 ? message[1] : null;
      final accepted = message.length > 2 && message[2] == true;
      final note = message.length > 3 ? '${message[3]}' : '';
      if (id is String) {
        final waiter = _okWaiters.remove(id);
        waiter?.complete(
          accepted || note.toLowerCase().startsWith('duplicate'),
        );
      }
      return;
    }
    if (type == 'EVENT' || type == 'EOSE' || type == 'CLOSED') {
      final subId = message.length > 1 ? message[1] : null;
      if (subId is! String) {
        return;
      }
      handlers[subId]?.call(type, message);
    }
  }

  void send(String payload) {
    if (!closed) {
      _channel.sink.add(payload);
    }
  }

  /// Resolves when the relay answers `OK` for [eventId] (false on timeout).
  Future<bool> waitForOk(String eventId, Duration timeout) {
    final completer = Completer<bool>();
    _okWaiters[eventId] = completer;
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _okWaiters.remove(eventId);
        return false;
      },
    );
  }

  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    for (final waiter in _okWaiters.values) {
      if (!waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    _okWaiters.clear();
    handlers.clear();
    await _subscription.cancel();
    try {
      await _channel.sink.close();
    } on Object {
      // Socket already gone.
    }
  }
}

/// Bookkeeping for one relay subscription (dedup + EOSE tracking).
class _SubHandle {
  _SubHandle({
    required this.id,
    required this.controller,
    required this.relayCount,
    required this.autoCloseOnEose,
  });

  final String id;
  final StreamController<NostrEvent> controller;
  final int relayCount;
  final bool autoCloseOnEose;
  final Set<String> seenEventIds = {};
  final Set<String> eoseRelays = {};

  /// Set by [NostrService._openSubscription]; closes REQ + stream.
  Future<void> Function()? onClose;

  bool closed = false;

  bool addIfNew(NostrEvent event) {
    final eventId = event.id;
    if (eventId == null) {
      return false;
    }
    return seenEventIds.add(eventId);
  }

  void noteEose(String relayUrl) {
    eoseRelays.add(relayUrl);
    if (autoCloseOnEose && eoseRelays.length >= relayCount) {
      unawaited(close());
    }
  }

  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    await onClose?.call();
  }
}
