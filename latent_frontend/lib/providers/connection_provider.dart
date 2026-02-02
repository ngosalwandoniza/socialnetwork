import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class ConnectionProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pendingConnections = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get connections => _connections;
  List<Map<String, dynamic>> get pendingConnections => _pendingConnections;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getConnections();
      _connections = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingConnections() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await ApiService.getPendingConnections();
      _pendingConnections = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acceptRequest(int connectionId) async {
    try {
      await ApiService.acceptConnection(connectionId);
      // Refresh both lists
      await loadPendingConnections();
      await loadConnections();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> rejectRequest(int connectionId) async {
    try {
      await ApiService.rejectConnection(connectionId);
      // Refresh pending list
      await loadPendingConnections();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> disconnect(int userId) async {
    try {
      await ApiService.disconnect(userId);
      await loadConnections();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
