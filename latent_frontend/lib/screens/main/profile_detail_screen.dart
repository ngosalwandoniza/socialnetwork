import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../chat/chat_detail_screen.dart';
import '../post/post_detail_screen.dart';
import '../post/collaborative_post_detail_screen.dart';

class ProfileDetailScreen extends StatefulWidget {
  final Map<String, dynamic> profile;

  const ProfileDetailScreen({super.key, required this.profile});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  late String _connectionStatus;
  bool _isProcessing = false;
  Map<String, dynamic>? _fullProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _connectionStatus = widget.profile['connection_status'] ?? 'NONE';
    _fetchProfileDetail();
  }

  Future<void> _fetchProfileDetail() async {
    try {
      final data = await ApiService.getProfile(widget.profile['id']);
      if (mounted) {
        setState(() {
          _fullProfile = data;
          _connectionStatus = data['connection_status'] ?? 'NONE';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleConnect() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final result = await ApiService.sendConnectionRequest(widget.profile['id']);
      setState(() {
        _connectionStatus = result['status'] ?? 'PENDING';
        _isProcessing = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_connectionStatus == 'PENDING' ? 'Connection request sent!' : 'Connected!')),
        );
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _handleMessage() {
    final id = widget.profile['id'];
    if (id == null) {
      debugPrint('Error: Profile ID is null. Profile: ${widget.profile}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: User ID not found')),
      );
      return;
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatDetailScreen(
          userId: id,
          userName: widget.profile['username'] ?? widget.profile['author_name'] ?? 'User',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _fullProfile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final displayProfile = _fullProfile ?? widget.profile;
    final username = displayProfile['username'] ?? displayProfile['author_name'] ?? 'User';
    final profilePic = displayProfile['profile_picture'] ?? displayProfile['author_pic'];
    final gender = displayProfile['gender'];
    final age = displayProfile['age'];
    final interests = displayProfile['interests'] as List?;
    final socialGravity = displayProfile['social_gravity'] ?? '1.0';

    return Scaffold(
      appBar: AppBar(
        title: Text(username),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textMain,
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryViolet, AppTheme.accentPink],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  child: CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.surfaceGray,
                      backgroundImage: profilePic != null ? NetworkImage(ApiService.getMediaUrl(profilePic)!) : null,
                      child: profilePic == null
                          ? const FaIcon(FontAwesomeIcons.user, size: 40, color: AppTheme.primaryViolet)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),

            // User Info
            Text(
              username,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Social Gravity: $socialGravity',
                  style: const TextStyle(color: AppTheme.primaryViolet, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 4),
                const FaIcon(FontAwesomeIcons.circleCheck, size: 14, color: AppTheme.primaryViolet),
              ],
            ),
            const SizedBox(height: 16),
            if (gender != null || age != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (gender != null) ...[
                      FaIcon(
                        gender == 'M' ? FontAwesomeIcons.mars : FontAwesomeIcons.venus,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        gender == 'M' ? 'Male' : 'Female',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    if (gender != null && age != null) const SizedBox(width: 16),
                    if (age != null)
                      Text(
                        '$age years old',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                children: [
                   if (_connectionStatus != 'CONNECTED')
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_connectionStatus == 'PENDING' || _isProcessing) ? null : _handleConnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _connectionStatus == 'PENDING' ? Colors.grey : AppTheme.primaryViolet,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isProcessing 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(
                              _connectionStatus == 'PENDING' ? 'Pending' : 'Connect', 
                              style: const TextStyle(fontWeight: FontWeight.bold)
                            ),
                      ),
                    ),
                  if (_connectionStatus == 'CONNECTED')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 50),
                          side: const BorderSide(color: AppTheme.primaryViolet),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Connected', style: TextStyle(color: AppTheme.primaryViolet, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: AppTheme.surfaceGray,
                    child: IconButton(
                      icon: const FaIcon(FontAwesomeIcons.solidMessage, size: 18, color: AppTheme.primaryViolet),
                      onPressed: _handleMessage,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Interests
            if (interests != null && interests.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Interests', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: interests
                          .map<Widget>((i) => Chip(
                                label: Text(i['name'] ?? ''),
                                backgroundColor: AppTheme.surfaceGray,
                                side: BorderSide.none,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Moments
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Moments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  FutureBuilder<List<dynamic>>(
                    future: ApiService.getUserPosts(widget.profile['id']),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: Column(
                            children: [
                              const FaIcon(FontAwesomeIcons.camera, size: 32, color: AppTheme.textSecondary),
                              const SizedBox(height: 8),
                              Text('No moments yet', style: TextStyle(color: AppTheme.textSecondary)),
                            ],
                          ),
                        );
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: snapshot.data!.length,
                        itemBuilder: (context, index) {
                          final post = snapshot.data![index];
                          return GestureDetector(
                            onTap: () {
                              if (post['is_collaborative'] == true) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CollaborativePostDetailScreen(post: post),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PostDetailScreen(post: post),
                                  ),
                                );
                              }
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: AppTheme.surfaceGray,
                                    child: post['image'] != null
                                        ? Image.network(
                                            ApiService.getMediaUrl(post['image'])!,
                                            fit: BoxFit.cover,
                                          )
                                        : Center(child: FaIcon(post['video'] != null ? FontAwesomeIcons.video : FontAwesomeIcons.pencil, size: 20, color: AppTheme.textSecondary)),
                                  ),
                                  if (post['post_type'] == 'PERSISTENT')
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryViolet,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const FaIcon(FontAwesomeIcons.solidStar, size: 8, color: Colors.white),
                                      ),
                                    ),
                                  if (post['is_collaborative'] == true)
                                    Positioned(
                                      bottom: 4,
                                      right: 4,
                                      child: FaIcon(FontAwesomeIcons.peopleGroup, size: 12, color: AppTheme.primaryViolet),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
