import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ChatProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _conversations = [];
  List<Map<String, dynamic>> _currentMessages = [];
  bool _isLoading = false;
  String? _error;
  int? _currentChatUserId;
  
  List<Map<String, dynamic>> get conversations => _conversations;
  List<Map<String, dynamic>> get currentMessages => _currentMessages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get totalUnreadCount => _conversations.fold(0, (sum, conv) => sum + (conv['unread_count'] as int? ?? 0));
  
  Future<void> loadConversations() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getConversations();
      _conversations = List<Map<String, dynamic>>.from(data);
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
  
  Future<void> sendMessage(int userId, String content) async {
    try {
      final message = await ApiService.sendMessage(userId, content);
      _currentMessages.add(message);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  void clearCurrentChat() {
    _currentMessages = [];
    _currentChatUserId = null;
    notifyListeners();
  }
}
