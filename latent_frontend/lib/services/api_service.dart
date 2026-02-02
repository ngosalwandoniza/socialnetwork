import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;

  static String? getMediaUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    return '${AppConfig.mediaBaseUrl}$path';
  }
  
  static Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();
  
  // Token Management
  static Future<String?> getToken() async {
    final prefs = await _prefs;
    return prefs.getString('access_token');
  }
  
  static Future<void> saveTokens(String accessToken, String refreshToken) async {
    final prefs = await _prefs;
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
  }
  
  static Future<void> clearTokens() async {
    final prefs = await _prefs;
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
  
  static Future<Map<String, String>> _authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Auth Endpoints
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/token/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await saveTokens(data['access'], data['refresh']);
      return data;
    } else {
      throw Exception(_parseError(response, 'Login failed'));
    }
  }
  
  static String _parseError(http.Response response, String defaultMsg) {
    try {
      final data = jsonDecode(response.body);
      if (data is Map) {
        if (data.containsKey('detail')) return data['detail'];
        // Handle field specific errors e.g. {"username": ["This field is required"]}
        final firstError = data.values.first;
        if (firstError is List && firstError.isNotEmpty) return firstError.first;
        if (firstError is String) return firstError;
      }
    } catch (_) {}
    return '$defaultMsg (${response.statusCode})';
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String gender,
    required int age,
    List<int>? interestIds,
    File? profilePicture,
  }) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/auth/register/'));
    request.fields['username'] = username;
    request.fields['password'] = password;
    request.fields['gender'] = gender;
    request.fields['age'] = age.toString();
    
    if (interestIds != null && interestIds.isNotEmpty) {
      for (var i = 0; i < interestIds.length; i++) {
        request.fields['interest_ids[$i]'] = interestIds[i].toString();
      }
    }

    if (profilePicture != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profile_picture',
        profilePicture.path,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      await login(username, password);
      return data;
    } else {
      throw Exception(_parseError(response, 'Failed to register'));
    }
  }
  
  static Future<void> logout() async {
    await clearTokens();
  }
  
  // Profile Endpoints
  static Future<Map<String, dynamic>> getMyProfile() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/profile/me/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get profile: ${response.body}');
    }
  }

  static Future<void> updateProfile({String? username, String? gender, int? age, File? profilePicture}) async {
    final headers = await _authHeaders();
    headers.remove('Content-Type'); // Let MultipartRequest handle this
    
    var request = http.MultipartRequest('PUT', Uri.parse('$baseUrl/profile/update/'));
    request.headers.addAll(headers);

    if (username != null) request.fields['username'] = username;
    if (gender != null) request.fields['gender'] = gender;
    if (age != null) request.fields['age'] = age.toString();

    if (profilePicture != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'profile_picture',
        profilePicture.path,
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update profile: ${response.body}');
    }
  }

  static Future<void> deleteAccount() async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/profile/delete/'),
      headers: headers,
    );
    
    if (response.statusCode != 204) {
      throw Exception('Failed to delete account: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> getProfile(int profileId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/profile/$profileId/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get profile: ${response.body}');
    }
  }
  
  static Future<List<dynamic>> getFeed() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/feed/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get feed: ${response.body}');
    }
  }

  static Future<List<dynamic>> getTrendingFeed() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/feed/trending/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get trending feed: ${response.body}');
    }
  }
  
  static Future<List<dynamic>> getUserPosts([int? userId]) async {
    final headers = await _authHeaders();
    final url = userId != null ? '$baseUrl/posts/?user_id=$userId' : '$baseUrl/posts/me/';
    final response = await http.get(
      Uri.parse(url),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get user posts: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> likePost(int postId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like/'),
      headers: headers,
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> addComment(int postId, String content) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/comment/'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add comment: ${response.body}');
    }
  }

  static Future<List<dynamic>> getComments(int postId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/posts/$postId/comments/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get comments: ${response.body}');
    }
  }

  static Future<List<dynamic>> getStreaks() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/streaks/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get streaks: ${response.body}');
    }
  }
  
  // Discovery Endpoints
  static Future<List<dynamic>> getSuggestedPeople() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/suggested/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get suggestions: ${response.body}');
    }
  }
  
  static Future<void> updateLocation(double latitude, double longitude) async {
    final headers = await _authHeaders();
    await http.post(
      Uri.parse('$baseUrl/location/'),
      headers: headers,
      body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
    );
  }

  static Future<void> disconnect(int userId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/connections/$userId/disconnect/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to disconnect');
    }
  }
  
  // Connection Endpoints
  static Future<List<dynamic>> getConnections() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/connections/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get connections: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> sendConnectionRequest(int receiverId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/connections/request/'),
      headers: headers,
      body: jsonEncode({'receiver_id': receiverId}),
    );
    
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send connection request: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> acceptConnection(int connectionId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/connections/$connectionId/accept/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to accept connection: ${response.body}');
    }
  }

  static Future<void> rejectConnection(int connectionId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/connections/$connectionId/reject/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to reject connection: ${response.body}');
    }
  }

  static Future<List<dynamic>> getPendingConnections() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/connections/pending/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get pending connections: ${response.body}');
    }
  }
  
  // Chat Endpoints
  static Future<List<dynamic>> getConversations() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/conversations/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get conversations: ${response.body}');
    }
  }
  
  static Future<List<dynamic>> getChatMessages(int userId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$userId/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get messages: ${response.body}');
    }
  }
  
  static Future<Map<String, dynamic>> sendMessage(int userId, String content) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/chat/$userId/send/'),
      headers: headers,
      body: jsonEncode({'content': content}),
    );
    
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to send message: ${response.body}');
    }
  }
  
  // Interests Endpoints
  static Future<List<dynamic>> getInterests() async {
    final response = await http.get(Uri.parse('$baseUrl/interests/'));
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get interests: ${response.body}');
    }
  }
  
  static Future<void> updateInterests(List<int> interestIds) async {
    final headers = await _authHeaders();
    await http.post(
      Uri.parse('$baseUrl/interests/update/'),
      headers: headers,
      body: jsonEncode({'interest_ids': interestIds}),
    );
  }

  // Sharing Helper
  static String getPostShareLink(int postId) {
    return "https://latent.app/p/$postId";
  }

  // Safety Endpoints
  static Future<void> blockUser(int userId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/users/$userId/block/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to block user: ${response.body}');
    }
  }

  static Future<void> unblockUser(int userId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/users/$userId/block/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to unblock user: ${response.body}');
    }
  }

  static Future<void> reportUser({
    required int reportedUserId,
    required String reason,
    int? reportedPostId,
    String? details,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/report/'),
      headers: headers,
      body: jsonEncode({
        'reported_user_id': reportedUserId,
        'reason': reason,
        if (reportedPostId != null) 'reported_post_id': reportedPostId,
        if (details != null) 'details': details,
      }),
    );
    
    if (response.statusCode != 201) {
      throw Exception('Failed to submit report: ${response.body}');
    }
  }

  static Future<void> updateFcmToken(String token) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/register-device/'),
      headers: headers,
      body: jsonEncode({'fcm_token': token}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to register device: ${response.body}');
    }
  }

  // Collaborative Posts Endpoints
  static Future<Map<String, dynamic>> inviteContributor(int postId, int contributorId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/invite/'),
      headers: headers,
      body: jsonEncode({'contributor_id': contributorId}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to invite contributor: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> contributeToPost(int postId, {String? text, File? image}) async {
    final headers = await _authHeaders();
    headers.remove('Content-Type'); // Let MultipartRequest handle this
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/posts/$postId/contribute/'),
    );
    request.headers.addAll(headers);
    
    if (text != null && text.isNotEmpty) {
      request.fields['text'] = text;
    }
    
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 200) {
      throw Exception('Failed to contribute: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> getPostContributors(int postId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/posts/$postId/contributors/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get contributors: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getCollaborativePosts() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/posts/collaborative/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to get collaborative posts: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> createPost({
    String? text,
    File? image,
    File? video,
    String postType = 'EPHEMERAL', // EPHEMERAL or PERSISTENT
  }) async {
    final headers = await _authHeaders();
    headers.remove('Content-Type');
    
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/posts/'),
    );
    request.headers.addAll(headers);
    
    if (text != null && text.isNotEmpty) {
      request.fields['content_text'] = text;
    }
    request.fields['post_type'] = postType;
    
    if (image != null) {
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
    }
    if (video != null) {
      request.files.add(await http.MultipartFile.fromPath('video', video.path));
    }
    
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode != 201) {
      throw Exception('Failed to create post: ${response.body}');
    }
    return jsonDecode(response.body);
  }

  // Notification Endpoints
  static Future<List<dynamic>> getNotifications() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get notifications');
    }
  }

  static Future<void> markNotificationRead(int notificationId) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/$notificationId/read/'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to mark notification as read');
    }
  }

  static Future<void> registerDevice(String fcmToken) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/register-device/'),
      headers: headers,
      body: jsonEncode({'fcm_token': fcmToken}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to register device');
    }
  }

  // Password Recovery Endpoints
  static Future<List<String>> generateRecoveryCodes() async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/codes/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return List<String>.from(data['codes']);
    } else {
      throw Exception('Failed to generate codes: ${response.body}');
    }
  }

  static Future<Map<String, dynamic>> initiateRecovery(String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/initiate/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username}),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(_parseError(response, 'Failed to initiate recovery'));
    }
  }

  static Future<void> approveRecovery(String token) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/approve/'),
      headers: headers,
      body: jsonEncode({'token': token}),
    );
    
    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to approve recovery'));
    }
  }

  static Future<void> resetPasswordWithCode({
    required String username,
    required String recoveryCode,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/reset/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'recovery_code': recoveryCode,
        'password': newPassword,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to reset password'));
    }
  }

  static Future<void> resetPasswordWithToken({
    required String username,
    required String token,
    required String newPassword,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/reset/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'token': token,
        'password': newPassword,
      }),
    );
    
    if (response.statusCode != 200) {
      throw Exception(_parseError(response, 'Failed to reset password'));
    }
  }

  static Future<List<dynamic>> getGuardians() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/recovery/guardians/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get guardians');
    }
  }

  static Future<void> updateGuardians(List<int> guardianIds) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/auth/recovery/guardians/'),
      headers: headers,
      body: jsonEncode({'guardian_ids': guardianIds}),
    );
    
    if (response.statusCode != 200) {
      throw Exception('Failed to update guardians');
    }
  }

  static Future<List<dynamic>> getPendingGuardianRequests() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/auth/recovery/pending-requests/'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get pending requests');
    }
  }
}
