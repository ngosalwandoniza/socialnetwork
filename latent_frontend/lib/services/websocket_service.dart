import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/config.dart';
import 'api_service.dart';

/// Manages a persistent WebSocket connection for real-time chat.
/// Falls back gracefully if the server doesn't support WebSockets.
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  // Stream controller to broadcast incoming messages to listeners  
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of incoming WebSocket events (new_message, typing, messages_read, etc.)
  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  /// Connect to the WebSocket server.
  Future<void> connect() async {
    if (_isConnected) return;

    final token = await ApiService.getToken();
    if (token == null) {
      debugPrint('WebSocket: No auth token, skipping connection');
      return;
    }

    // Convert HTTP base URL to WebSocket URL
    final wsBase = AppConfig.baseUrl
        .replaceFirst('http://', 'ws://')
        .replaceFirst('https://', 'wss://')
        .replaceFirst('/api', '');

    final wsUrl = '$wsBase/ws/chat/0/?token=$token';

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          _reconnectAttempts = 0;
          try {
            final decoded = jsonDecode(data as String);
            if (decoded is Map<String, dynamic>) {
              _messageController.add(decoded);
            }
          } catch (e) {
            debugPrint('WebSocket decode error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket closed');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      _isConnected = true;
      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  /// Send a text chat message via WebSocket.
  void sendMessage(int receiverId, String content) {
    _send({
      'type': 'chat_message',
      'receiver_id': receiverId,
      'content': content,
    });
  }

  /// Send a typing indicator.
  void sendTyping(int receiverId) {
    _send({
      'type': 'typing',
      'receiver_id': receiverId,
    });
  }

  /// Mark messages from a sender as read.
  void markRead(int senderId) {
    _send({
      'type': 'mark_read',
      'sender_id': senderId,
    });
  }

  void _send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    } else {
      debugPrint('WebSocket not connected, message queued or dropped');
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: max reconnect attempts reached');
      return;
    }

    final delay = _reconnectDelay * (_reconnectAttempts + 1);
    _reconnectAttempts++;
    debugPrint('WebSocket: reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)');

    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  /// Disconnect and clean up.
  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
