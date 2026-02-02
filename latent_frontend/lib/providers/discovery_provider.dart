import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class DiscoveryProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  String? _currentLocation;
  
  List<Map<String, dynamic>> get suggestions => _suggestions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentLocation => _currentLocation;
  
  Future<void> loadSuggestions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getSuggestedPeople();
      _suggestions = List<Map<String, dynamic>>.from(data);
      _isLoading = false;
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
    try {
      await ApiService.sendConnectionRequest(userId);
      // Update local state
      final index = _suggestions.indexWhere((s) => s['id'] == userId);
      if (index != -1) {
        _suggestions[index]['connection_status'] = 'PENDING';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
  
  Future<void> disconnect(int userId) async {
    try {
      await ApiService.disconnect(userId);
      // Update local state
      final index = _suggestions.indexWhere((s) => s['id'] == userId);
      if (index != -1) {
        _suggestions[index]['connection_status'] = 'NONE';
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
