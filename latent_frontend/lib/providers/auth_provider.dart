import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _currentUser;
  String? _error;
  
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  Map<String, dynamic>? get currentUser => _currentUser;
  String? get error => _error;
  
  Future<void> checkAuthStatus() async {
    final token = await ApiService.getToken();
    if (token != null) {
      try {
        _currentUser = await ApiService.getMyProfile();
        _isLoggedIn = true;
      } catch (e) {
        _isLoggedIn = false;
        await ApiService.clearTokens();
      }
    }
    notifyListeners();
  }
  
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await ApiService.login(username, password);
      _currentUser = await ApiService.getMyProfile();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<bool> register({
    required String username,
    required String password,
    required String gender,
    required int age,
    List<int>? interestIds,
    File? profilePicture,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      await ApiService.register(
        username: username,
        password: password,
        gender: gender,
        age: age,
        interestIds: interestIds,
        profilePicture: profilePicture,
      );
      _currentUser = await ApiService.getMyProfile();
      _isLoggedIn = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  Future<void> logout() async {
    await ApiService.logout();
    _isLoggedIn = false;
    _currentUser = null;
    notifyListeners();
  }
  
  Future<void> refreshProfile() async {
    try {
      _currentUser = await ApiService.getMyProfile();
      notifyListeners();
    } catch (e) {
      // Handle error silently
    }
  }
}
