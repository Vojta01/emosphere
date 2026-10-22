// Retry-on-reconnect behaviour of [NostrService.publishEvent].
//
// Guards the "Odeslání se nepovedlo" failure mode: a websocket that died
// without `onDone` (phone sleep, NAT timeout) silently buffers writes, so
// every publish timed out until the page was reloaded. The service now drops
// the connections and retries once on fresh sockets.

import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart' hide NostrException;
import 'package:emosphere/core/models/checkin.dart';
import 'package:emosphere/core/models/emotion.dart';
import 'package:emosphere/core/nostr/nostr_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// In-memory [WebSocketChannel] driven by the test.
class FakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeChannel({this.autoAck = true}) {
    // Drain the outgoing stream so `sink.close()` completes — a never-listened
    // StreamController never finishes its close future.
    _outgoing.stream.listen((_) {}, onError: (Object _) {});
  }

  /// When `true`, every `EVENT` is answered with an accepting `OK`.
  final bool autoAck;

  /// Payloads the service sent, in order.
  final List<String> sent = <String>[];

  final StreamController<dynamic> _incoming = StreamController<dynamic>();
  final StreamController<dynamic> _outgoing = StreamController<dynamic>();

  @override
  Future<void> get ready => Future<void>.value();

  @override
  String? get protocol => null;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  WebSocketSink get sink => _FakeSink(this);

  /// Pushes one raw relay message into the service.
  void emit(String message) {
    if (!_incoming.isClosed) {
      _incoming.add(message);
    }
  }

  void _record(String payload) {
    sent.add(payload);
    if (!autoAck) {
      return;
    }
    try {
      final decoded = jsonDecode(payload);
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0] == 'EVENT' &&
          decoded[1] is Map) {
        final id = (decoded[1] as Map)['id'];
        scheduleMicrotask(
          () => emit(jsonEncode(<dynamic>['OK', id, true, ''])),
        );
      }
    } on FormatException {
      // Not JSON — nothing to acknowledge.
    }
  }
}

class _FakeSink implements WebSocketSink {
  _FakeSink(this._channel);

  final FakeChannel _channel;

  @override
  void add(dynamic data) {
    if (data is String) {
      _channel._record(data);
    }
    _channel._outgoing.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _channel._outgoing.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) =>
      _channel._outgoing.addStream(stream);

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      _channel._outgoing.close();

  @override
  Future<void> get done => _channel._outgoing.done;
}

/// Polls [condition] for up to a second.
Future<void> until(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition not reached in time.');
}

NostrEvent buildCheckin() {
  return CheckinEvent.buildEvent(
    emotion: Emotion.joy,
    intensity: 3,
    keyPairs: NostrKeyPairs.generate(),
  );
}

void main() {
  test('publishEvent retries on fresh sockets when no relay acknowledges',
      () async {
    final channels = <FakeChannel>[];
    final service = NostrService(
      relays: <String>['wss://one.test', 'wss://two.test'],
      publishTimeout: const Duration(milliseconds: 200),
      channelFactory: (Uri uri) {
        // The first pair models stale sockets: the write is swallowed.
        final channel = FakeChannel(autoAck: channels.length >= 2);
        channels.add(channel);
        return channel;
      },
    );
    final event = buildCheckin();

    await service.publishEvent(event);

    expect(channels, hasLength(4), reason: 'two dropped + two fresh');
    expect(channels[0].autoAck, isFalse);
    expect(channels[1].autoAck, isFalse);
    for (final channel in channels.sublist(2)) {
      expect(
        channel.sent.any((message) => message.contains(event.id!)),
        isTrue,
        reason: 'the retry must carry the same event id',
      );
    }
  });

  test('publishEvent throws when even the retry gets no acknowledgment',
      () async {
    final channels = <FakeChannel>[];
    final service = NostrService(
      relays: <String>['wss://one.test'],
      publishTimeout: const Duration(milliseconds: 120),
      channelFactory: (Uri uri) {
        final channel = FakeChannel(autoAck: false);
        channels.add(channel);
        return channel;
      },
    );

    await expectLater(
      service.publishEvent(buildCheckin()),
      throwsA(isA<NostrException>()),
    );
    expect(channels, hasLength(2), reason: 'both attempts connected');
  });

  test('refreshStaleConnections replaces silent sockets and replays the REQ',
      () async {
    final channels = <FakeChannel>[];
    final service = NostrService(
      relays: <String>['wss://one.test'],
      channelFactory: (Uri uri) {
        final channel = FakeChannel(autoAck: false);
        channels.add(channel);
        return channel;
      },
    );

    final subscription = service.subscribeCheckins().listen((_) {});
    await until(
      () =>
          channels.isNotEmpty &&
          channels[0].sent.any((message) => message.startsWith('["REQ"')),
    );

    await service.refreshStaleConnections(maxIdle: Duration.zero);

    await until(
      () =>
          channels.length >= 2 &&
          channels[1].sent.any((message) => message.startsWith('["REQ"')),
    );
    expect(
      channels[0].sent.any((message) => message.startsWith('["REQ"')),
      isTrue,
      reason: 'the first connection had the REQ before it went stale',
    );
    // Cancelling an async* generator parked on `await for` does not complete
    // until the stream ends (Dart semantics), so fire and forget.
    unawaited(subscription.cancel());
  });
}
