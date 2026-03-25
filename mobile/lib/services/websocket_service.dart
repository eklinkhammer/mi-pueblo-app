import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fence/config.dart';
import 'package:fence/services/api_client.dart';

final websocketServiceProvider = Provider<WebSocketService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final service = WebSocketService(apiClient);
  ref.onDispose(service.shutdown);
  return service;
});

class WebSocketService {
  final ApiClient _apiClient;
  WebSocketChannel? _channel;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final Set<String> _joinedTopics = {};
  int _ref = 0;
  bool _connected = false;

  WebSocketService(this._apiClient, {WebSocketChannel? channel}) {
    if (channel != null) {
      _channel = channel;
    }
  }

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _connected;

  Set<String> get joinedGroupIds =>
      _joinedTopics.map((t) => t.replaceFirst('group:', '')).toSet();

  Future<void> connect() async {
    final token = await _apiClient.getAccessToken();
    if (token == null) return;

    try {
      if (_channel == null) {
        final uri =
            Uri.parse('${AppConfig.wsBaseUrl}?token=$token&vsn=2.0.0');
        _channel = WebSocketChannel.connect(uri);
      }
      _connected = true;

      _channel!.stream.listen(
        (data) {
          final message = jsonDecode(data as String);
          _handleMessage(message);
        },
        onError: (Object error) {
          _connected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _connected = false;
          _scheduleReconnect();
        },
      );

      _startHeartbeat();

      // Rejoin any previously joined topics
      for (final topic in _joinedTopics.toList()) {
        _sendJoin(topic);
      }
    } on Exception catch (_) {
      _connected = false;
      _scheduleReconnect();
    }
  }

  void joinGroup(String groupId) {
    final topic = 'group:$groupId';
    _joinedTopics.add(topic);
    if (_connected) {
      _sendJoin(topic);
    }
  }

  void leaveGroup(String groupId) {
    final topic = 'group:$groupId';
    _joinedTopics.remove(topic);
    if (_connected) {
      _send(topic, 'phx_leave', {});
    }
  }

  void sendLocationUpdate(String groupId, Map<String, dynamic> location) {
    _send('group:$groupId', 'location:update', location);
  }

  void _sendJoin(String topic) {
    _send(topic, 'phx_join', {});
  }

  void _send(String topic, String event, Map<String, dynamic> payload) {
    if (_channel == null || !_connected) return;
    _ref++;
    final message = [null, '$_ref', topic, event, payload];
    _channel!.sink.add(jsonEncode(message));
  }

  void _handleMessage(dynamic message) {
    if (message is! List || message.length < 5) return;

    final topic = message[2] as String?;
    final event = message[3] as String?;
    final payload = message[4];

    if (event == 'phx_reply' || event == 'phx_error') return;

    if (topic != null && event != null && payload is Map) {
      _messageController.add({
        'topic': topic,
        'event': event,
        'payload': Map<String, dynamic>.from(payload),
      });
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send('phoenix', 'heartbeat', {});
    });
  }

  void _scheduleReconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), connect);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _connected = false;
  }

  void shutdown() {
    dispose();
    _messageController.close();
  }
}
