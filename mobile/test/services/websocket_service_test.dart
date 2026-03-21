import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:fence/services/websocket_service.dart';
import '../helpers/mocks.dart';

class FakeSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool closed = false;

  @override
  void add(dynamic data) => messages.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> get done => Future.value();

  @override
  Future<dynamic> addStream(Stream stream) => Future.value();
}

class FakeChannel extends Fake implements WebSocketChannel {
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  final FakeSink _sink = FakeSink();

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  FakeSink get sink => _sink;

  void injectMessage(dynamic message) {
    _streamController.add(jsonEncode(message));
  }

  void close() {
    _streamController.close();
  }
}

void main() {
  late MockApiClient mockApi;
  late FakeChannel fakeChannel;
  late WebSocketService service;

  setUp(() {
    mockApi = MockApiClient();
    fakeChannel = FakeChannel();
    service = WebSocketService(mockApi, channel: fakeChannel);
  });

  tearDown(() {
    service.dispose();
    fakeChannel.close();
  });

  group('message parsing', () {
    test('ignores messages shorter than 5 elements', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();

      final messages = <Map<String, dynamic>>[];
      service.messages.listen(messages.add);

      fakeChannel.injectMessage([null, '1', 'topic']);
      await Future<void>.delayed(Duration.zero);

      expect(messages, isEmpty);
    });

    test('ignores phx_reply events', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();

      final messages = <Map<String, dynamic>>[];
      service.messages.listen(messages.add);

      fakeChannel.injectMessage(
          [null, '1', 'group:abc', 'phx_reply', {'status': 'ok'}]);
      await Future<void>.delayed(Duration.zero);

      expect(messages, isEmpty);
    });

    test('ignores phx_error events', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();

      final messages = <Map<String, dynamic>>[];
      service.messages.listen(messages.add);

      fakeChannel.injectMessage(
          [null, '1', 'group:abc', 'phx_error', {'reason': 'crash'}]);
      await Future<void>.delayed(Duration.zero);

      expect(messages, isEmpty);
    });

    test('broadcasts valid messages', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();

      final messages = <Map<String, dynamic>>[];
      service.messages.listen(messages.add);

      fakeChannel.injectMessage([
        null,
        '1',
        'group:abc',
        'location:update',
        {'lat': 37.7, 'lng': -122.4}
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(messages, hasLength(1));
      expect(messages.first['topic'], 'group:abc');
      expect(messages.first['event'], 'location:update');
      expect(messages.first['payload']['lat'], 37.7);
    });
  });

  group('topic management', () {
    test('joinGroup adds topic and sends join when connected', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();
      service.joinGroup('group-123');

      final sent = fakeChannel.sink.messages;
      // Find the join message (skip heartbeat setup messages)
      final joinMsg = sent
          .map((m) => jsonDecode(m as String) as List)
          .where((m) => m[3] == 'phx_join' && m[2] == 'group:group-123')
          .toList();

      expect(joinMsg, hasLength(1));
    });

    test('leaveGroup removes topic and sends leave when connected', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();
      service.joinGroup('group-123');
      service.leaveGroup('group-123');

      final sent = fakeChannel.sink.messages;
      final leaveMsg = sent
          .map((m) => jsonDecode(m as String) as List)
          .where((m) => m[3] == 'phx_leave' && m[2] == 'group:group-123')
          .toList();

      expect(leaveMsg, hasLength(1));
    });
  });

  group('protocol format', () {
    test('messages use [null, ref, topic, event, payload] format', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();
      service.joinGroup('test-group');

      final sent = fakeChannel.sink.messages;
      final decoded = jsonDecode(sent.last as String) as List;

      expect(decoded[0], isNull); // join_ref
      expect(decoded[1], isA<String>()); // ref (stringified int)
      expect(decoded[2], 'group:test-group'); // topic
      expect(decoded[3], 'phx_join'); // event
      expect(decoded[4], isA<Map>()); // payload
    });

    test('sendLocationUpdate sends correct Phoenix message format', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();
      service.joinGroup('g1');
      service.sendLocationUpdate('g1', {'lat': 37.7, 'lng': -122.4});

      final sent = fakeChannel.sink.messages;
      final decoded = jsonDecode(sent.last as String) as List;

      expect(decoded[2], 'group:g1');
      expect(decoded[3], 'location:update');
      expect(decoded[4]['lat'], 37.7);
      expect(decoded[4]['lng'], -122.4);
    });

    test('ref increments with each message', () async {
      when(() => mockApi.getAccessToken())
          .thenAnswer((_) async => 'token');

      await service.connect();
      service.joinGroup('g1');
      service.joinGroup('g2');

      final sent = fakeChannel.sink.messages;
      final refs = sent
          .map((m) => jsonDecode(m as String) as List)
          .map((m) => int.parse(m[1] as String))
          .toList();

      // Each ref should be unique and incrementing
      for (var i = 1; i < refs.length; i++) {
        expect(refs[i], greaterThan(refs[i - 1]));
      }
    });
  });

  group('connect edge cases', () {
    test('connect does nothing when no access token', () async {
      when(() => mockApi.getAccessToken()).thenAnswer((_) async => null);

      await service.connect();

      expect(service.isConnected, isFalse);
      expect(fakeChannel.sink.messages, isEmpty);
    });

    test('sendLocationUpdate does nothing when disconnected', () {
      // Don't call connect - service is disconnected
      service.sendLocationUpdate('g1', {'lat': 0.0});

      expect(fakeChannel.sink.messages, isEmpty);
    });
  });
}
