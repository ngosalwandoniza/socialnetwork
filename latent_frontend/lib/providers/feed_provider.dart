import 'package:flutter/foundation.dart';
import '../services/api_service.dart';

class FeedProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _posts = [];
  List<Map<String, dynamic>> _trendingPosts = [];
  bool _isLoading = false;
  bool _isTrending = false;
  String? _error;
  
  List<Map<String, dynamic>> get posts => _isTrending ? _trendingPosts : _posts;
  bool get isLoading => _isLoading;
  bool get isTrending => _isTrending;
  String? get error => _error;
  
  Future<void> loadFeed() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getFeed();
      _posts = List<Map<String, dynamic>>.from(data);
      _isTrending = false;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTrendingFeed() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    
    try {
      final data = await ApiService.getTrendingFeed();
      _trendingPosts = List<Map<String, dynamic>>.from(data);
      _isTrending = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> refresh() async {
    if (_isTrending) {
      await loadTrendingFeed();
    } else {
      await loadFeed();
    }
  }

  Future<void> createPost(String content, {dynamic image, dynamic video, String postType = 'EPHEMERAL'}) async {
    try {
      await ApiService.createPost(text: content, image: image, video: video, postType: postType);
      await loadFeed(); // Refresh feed after posting
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> inviteContributor(int postId, int contributorId) async {
    try {
      await ApiService.inviteContributor(postId, contributorId);
      // Optional: Update local post state if needed
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> contributeToPost(int postId, {String? text, dynamic image}) async {
    try {
      await ApiService.contributeToPost(postId, text: text, image: image);
      await loadFeed(); // Refresh feed after contributing
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<dynamic>> getCollaborativePosts() async {
    try {
      return await ApiService.getCollaborativePosts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<Map<String, dynamic>> getPostContributors(int postId) async {
    try {
      return await ApiService.getPostContributors(postId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return {};
    }
  }
  
  Future<void> likePost(int postId) async {
    try {
      final result = await ApiService.likePost(postId);
      final listToUpdate = _isTrending ? _trendingPosts : _posts;
      final index = listToUpdate.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        listToUpdate[index]['is_liked'] = result['liked'];
        listToUpdate[index]['likes_count'] = result['liked'] 
            ? (listToUpdate[index]['likes_count'] ?? 0) + 1 
            : (listToUpdate[index]['likes_count'] ?? 1) - 1;
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }

  Future<List<Map<String, dynamic>>> getComments(int postId) async {
    try {
      final data = await ApiService.getComments(postId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      return [];
    }
  }

  Future<void> addComment(int postId, String content) async {
    try {
      await ApiService.addComment(postId, content);
      // Refresh likes/comments count locally or just reload specific post if needed
      final listToUpdate = _isTrending ? _trendingPosts : _posts;
      final index = listToUpdate.indexWhere((p) => p['id'] == postId);
      if (index != -1) {
        listToUpdate[index]['comments_count'] = (listToUpdate[index]['comments_count'] ?? 0) + 1;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
