import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DiscoveryProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _suggestions = [];
  List<Map<String, dynamic>> _leaderboard = [];
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = false;
  bool _isLeaderboardLoading = false;
  bool _isFriendsLoading = false;
  String? _error;
  String? _currentLocation;
  
  int _currentPage = 1;
  bool _hasNextPage = true;

  List<Map<String, dynamic>> get suggestions => _suggestions;
  List<Map<String, dynamic>> get leaderboard => _leaderboard;
  List<Map<String, dynamic>> get friends => _friends;
  bool get isLoading => _isLoading;
  bool get isLeaderboardLoading => _isLeaderboardLoading;
  bool get isFriendsLoading => _isFriendsLoading;
  String? get error => _error;
  String? get currentLocation => _currentLocation;
  bool get hasNextPage => _hasNextPage;

  Future<void> loadLeaderboard() async {
    _isLeaderboardLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getLeaderboard();
      _leaderboard = List<Map<String, dynamic>>.from(data);
      _isLeaderboardLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLeaderboardLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFriends() async {
    _isFriendsLoading = true;
    notifyListeners();
    try {
      final data = await ApiService.getConnections();
      // Connections data is slightly different, we need to extract the 'other' profile
      _friends = List<Map<String, dynamic>>.from(data.map((c) {
        // Return the profile that is NOT the current user
        // But since the API returns sender/receiver, we just need the other one
        // For simplicity, let's assume the API returns what we need or adjust it here
        // Usually ConnectionSerializer returns sender and receiver info.
        return c; // We'll handle mapping in the UI or adjust here if we have user info
      }));
      _isFriendsLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isFriendsLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> loadSuggestions({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _suggestions = [];
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getSuggestedPeople(page: _currentPage);
      final newSuggestions = List<Map<String, dynamic>>.from(data['results']);
      _suggestions.addAll(newSuggestions);
      _hasNextPage = data['has_next'];
      _isLoading = false;
      if (_hasNextPage) _currentPage++;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> updateLocation(double latitude, double longitude) async {
    try {
      await ApiService.updateLocation(latitude, longitude);
      await loadSuggestions(); // Refresh suggestions with new location
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> sendConnectionRequest(int userId) async {
    final index = _suggestions.indexWhere((s) => s['id'] == userId);
    if (index == -1) return;

    final originalStatus = _suggestions[index]['connection_status'];
    
    // Optimistic Update
    _suggestions[index]['connection_status'] = 'PENDING';
    notifyListeners();

    try {
      await ApiService.sendConnectionRequest(userId);
      // Success: status is already PENDING
    } catch (e) {
      // Rollback
      _suggestions[index]['connection_status'] = originalStatus;
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> disconnect(int userId) async {
    final index = _suggestions.indexWhere((s) => s['id'] == userId);
    if (index == -1) return;

    final originalStatus = _suggestions[index]['connection_status'];

    // Optimistic Update
    _suggestions[index]['connection_status'] = 'NONE';
    notifyListeners();

    try {
      await ApiService.disconnect(userId);
    } catch (e) {
      // Rollback
      _suggestions[index]['connection_status'] = originalStatus;
      _error = e.toString();
      notifyListeners();
    }
  }
}
