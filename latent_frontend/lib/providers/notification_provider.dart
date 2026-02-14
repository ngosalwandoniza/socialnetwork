import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/sync_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _notifications.where((n) => n['is_read'] == false).length;

  void startPolling() {
    SyncService().register(pollUpdate);
  }

  void stopPolling() {
    SyncService().unregister(pollUpdate);
  }

  Future<void> pollUpdate() async {
    try {
      final data = await ApiService.getNotifications();
      final newNotifications = List<Map<String, dynamic>>.from(data);
      
      _notifications = newNotifications;
      notifyListeners();
    } catch (e) {
      debugPrint("Notification polling error: $e");
    }
  }

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getNotifications();
      _notifications = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      await ApiService.markNotificationRead(notificationId);
      final index = _notifications.indexWhere((n) => n['id'] == notificationId);
      if (index != -1) {
        _notifications[index]['is_read'] = true;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> registerDevice(String token) async {
    try {
      await ApiService.registerDevice(token);
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}
