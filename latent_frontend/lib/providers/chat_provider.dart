import 'dart:async';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../utils/media_helper.dart';
import '../services/local_db.dart';
import 'dart:io';

class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _currentMessages = [];
  bool _isLoading = false;
  String? _error;
  int? _currentChatUserId;
  Timer? _pollTimer;
  
  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount => _conversations.fold(0, (sum, conv) => sum + (conv['unread_count'] as int? ?? 0));
  
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _pollUpdate();
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollUpdate() async {
    // Silently update conversations
    try {
      final convs = await ApiService.getConversations();
      _conversations = List<Map<String, dynamic>>.from(convs);
      
      // If we are in a chat, update messages too
      if (_currentChatUserId != null) {
        final msgs = await ApiService.getChatMessages(_currentChatUserId!);
        final newMsgs = List<Map<String, dynamic>>.from(msgs);
        
        // Only update if count changed (simple check)
        if (newMsgs.length != _currentMessages.length) {
          _currentMessages = newMsgs;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Polling error: $e");
    }
  }

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
  
  Future<void> loadMessages(int userId) async {
    _currentChatUserId = userId;
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getChatMessages(userId);
      _currentMessages = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> sendMessage(int userId, {String? content, File? image, File? video, bool isOptimistic = false}) async {
    Map<String, dynamic>? optimisticMsg;
    
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
      // Compress if media exists
      File? finalImage = image;
      File? finalVideo = video;

      if (image != null) {
        final compressed = await MediaHelper.compressImage(image);
        if (compressed != null) finalImage = compressed;
      } else if (video != null) {
        final compressed = await MediaHelper.compressVideo(video);
        if (compressed != null) finalVideo = compressed;
      }

      final message = await ApiService.sendMessage(userId, content: content, image: finalImage, video: finalVideo);
      
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
  
  void clearCurrentChat() {
    _currentMessages = [];
    _currentChatUserId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
