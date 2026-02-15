import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';
import '../services/websocket_service.dart';
import '../utils/media_helper.dart';
import '../services/local_db.dart';
import 'dart:io';
import 'package:video_compress/video_compress.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _currentMessages = [];
  bool _isLoading = false;
  String? _error;
  int? _currentChatUserId;
  int _chatPage = 1;
  bool _hasNextMessages = true;
  StreamSubscription? _wsSubscription;

  final Map<int, Timer> _typingTimers = {};
  final Set<int> _typingUsers = {};

  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  bool get hasNextMessages => _hasNextMessages;
  String? get error => _error;
  
  bool isUserTyping(int userId) => _typingUsers.contains(userId);

  int get totalUnreadCount => _conversations.fold<int>(
    0, (sum, c) => sum + ((c['unread_count'] as int?) ?? 0),
  );

  // ─── Polling (fallback when WebSocket is unavailable) ───

  void startPolling() {
    SyncService().register(pollUpdate);
    // Also connect WebSocket for real-time delivery
    _connectWebSocket();
  }

  void stopPolling() {
    SyncService().unregister(pollUpdate);
    _disconnectWebSocket();
  }

  Future<void> pollUpdate() async {
    // Silently update conversations
    try {
      final convs = await ApiService.getConversations();
      _conversations = List<Map<String, dynamic>>.from(convs);
      
      // If WebSocket is connected, skip HTTP message polling (WS handles it)
      if (!WebSocketService().isConnected && _currentChatUserId != null) {
        final data = await ApiService.getChatMessages(_currentChatUserId!, page: 1);
        final latestMsgs = List<Map<String, dynamic>>.from(data['results'] ?? []);
        
        // Merge: keep all existing messages, append only new ones by ID
        final existingIds = _currentMessages
            .where((m) => m['id'] != null && m['id'] > 0)
            .map((m) => m['id'])
            .toSet();
        
        for (final msg in latestMsgs) {
          if (msg['id'] != null && !existingIds.contains(msg['id'])) {
            _currentMessages.add(msg);
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

  // ─── WebSocket Integration ───

  void _connectWebSocket() {
    WebSocketService().connect();
    _wsSubscription?.cancel();
    _wsSubscription = WebSocketService().messages.listen(_onWebSocketEvent);
  }

  void _disconnectWebSocket() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
  }

  void _onWebSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];

    switch (type) {
      case 'new_message':
        _handleIncomingMessage(event['message']);
        break;
      case 'message_sent':
        _handleMessageSent(event['message']);
        break;
      case 'typing':
        _handleTypingIndicator(event);
        break;
      case 'messages_read':
        // Could update UI to show read receipts
        break;
    }
  }

  void _handleIncomingMessage(Map<String, dynamic>? message) {
    if (message == null) return;

    // Check if this message belongs to the current chat
    final senderId = message['sender'];
    if (_currentChatUserId != null && senderId == _currentChatUserId) {
      // Avoid duplicates
      final exists = _currentMessages.any((m) => m['id'] == message['id']);
      if (!exists) {
        _currentMessages.add(message);
        notifyListeners();
      }
    }

    // Also refresh conversations list for unread counts
    _refreshConversations();
  }

  void _handleMessageSent(Map<String, dynamic>? message) {
    if (message == null) return;

    // Replace optimistic message if present, or add the confirmed message
    final tempIndex = _currentMessages.indexWhere(
      (m) => m['is_sending'] == true && m['content'] == message['content'],
    );
    if (tempIndex != -1) {
      _currentMessages[tempIndex] = message;
    } else {
      // Avoid duplicate
      final exists = _currentMessages.any((m) => m['id'] == message['id']);
      if (!exists) {
        _currentMessages.add(message);
      }
    }
    notifyListeners();
  }

  void _handleTypingIndicator(Map<String, dynamic> event) {
    final senderId = event['sender_id'] as int?;
    if (senderId == null) return;

    // Add to typing set
    _typingUsers.add(senderId);
    
    // Reset/Start timer to clear typing state after 5 seconds
    _typingTimers[senderId]?.cancel();
    _typingTimers[senderId] = Timer(const Duration(seconds: 5), () {
      _typingUsers.remove(senderId);
      _typingTimers.remove(senderId);
      notifyListeners();
    });

    notifyListeners();
  }

  Future<void> _refreshConversations() async {
    try {
      final convs = await ApiService.getConversations();
      _conversations = List<Map<String, dynamic>>.from(convs);
      notifyListeners();
    } catch (e) {
      debugPrint("Conversation refresh error: $e");
    }
  }

  // ─── Conversations & Messages (HTTP) ───

  Future<void> loadConversations({bool refresh = false}) async {
    if (refresh) {
      _conversations = [];
    } else if (_conversations.isEmpty) {
      // Load from local DB for instant display
      final localConvs = await LocalDatabase().getConversations();
      if (localConvs.isNotEmpty && _conversations.isEmpty) {
        _conversations = localConvs;
        notifyListeners();
      }
    }

    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getConversations();
      _conversations = List<Map<String, dynamic>>.from(data);
      
      // Save for next time
      LocalDatabase().saveConversations(_conversations);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadMessages(int userId, {bool refresh = true}) async {
    if (refresh) {
      _chatPage = 1;
      _hasNextMessages = true;
      _currentMessages = [];
      _currentChatUserId = userId;
    }

    if (_chatPage == 1) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }
    
    try {
      final data = await ApiService.getChatMessages(userId, page: _chatPage);
      final newMsgs = List<Map<String, dynamic>>.from(data['results'] ?? []);
      
      if (_chatPage == 1) {
        _currentMessages = newMsgs;
      } else {
        // Insert at the beginning since they are historical
        _currentMessages.insertAll(0, newMsgs);
      }
      
      _hasNextMessages = data['has_next'] ?? false;
      _isLoading = false;

      // Mark messages as read via WebSocket if connected
      if (WebSocketService().isConnected) {
        WebSocketService().markRead(userId);
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreMessages() async {
    if (_isLoading || !_hasNextMessages || _currentChatUserId == null) return;
    _chatPage++;
    await loadMessages(_currentChatUserId!, refresh: false);
  }
  
  Future<void> sendMessage(int userId, {String? content, File? image, File? video, bool isOptimistic = false}) async {
    Map<String, dynamic>? optimisticMsg;
    
    // Try sending text-only messages via WebSocket for instant delivery
    final useWebSocket = WebSocketService().isConnected && 
                          content != null && content.trim().isNotEmpty && 
                          image == null && video == null;

    if (isOptimistic) {
      // Create a temporary message for Optimistic UI
      optimisticMsg = {
        'id': -DateTime.now().millisecondsSinceEpoch, // Negative ID for local-only
        'sender': -1, // Placeholder
        'content': content,
        'image': image?.path, // Local path for immediate preview
        'video': video?.path,
        'timestamp': DateTime.now().toIso8601String(),
        'is_read': false,
        'is_sending': true, // Custom flag for UI status
      };
      
      _currentMessages.add(optimisticMsg);
      notifyListeners();
    }

    try {
      if (useWebSocket) {
        // Send via WebSocket (instant, text-only)
        WebSocketService().sendMessage(userId, content!);
        // The message_sent event from WS will replace the optimistic message
        return;
      }

      // Fallback: Send via HTTP (required for media attachments)
      File? finalImage = image;
      File? finalVideo = video;
      File? thumbnailFile;

      if (image != null) {
        final compressed = await MediaHelper.compressImage(image);
        if (compressed != null) finalImage = compressed;
      } else if (video != null) {
        // Generate thumbnail before compression
        thumbnailFile = await VideoCompress.getFileThumbnail(
          video.path,
          quality: 50,
          position: -1,
        );
        
        final compressed = await MediaHelper.compressVideo(video);
        if (compressed != null) finalVideo = compressed;
      }

      final message = await ApiService.sendMessage(
        userId, 
        content: content, 
        image: finalImage, 
        video: finalVideo, 
        thumbnail: thumbnailFile
      );
      
      if (isOptimistic && optimisticMsg != null) {
        // Replace optimistic message with actual server response
        final index = _currentMessages.indexOf(optimisticMsg);
        if (index != -1) {
          _currentMessages[index] = message;
        }
      } else {
        _currentMessages.add(message);
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (isOptimistic && optimisticMsg != null) {
        // Remove the optimistic message on failure
        _currentMessages.remove(optimisticMsg);
      }
      notifyListeners();
    }
  }

  /// Send typing indicator to the current chat partner.
  void sendTyping() {
    if (_currentChatUserId != null && WebSocketService().isConnected) {
      WebSocketService().sendTyping(_currentChatUserId!);
    }
  }
  
  void clearCurrentChat() {
    _currentMessages = [];
    _currentChatUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
