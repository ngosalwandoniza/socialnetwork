import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/landing_page.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import '../../services/api_service.dart';
import '../post/collaborative_post_detail_screen.dart';
import '../post/post_detail_screen.dart';
import 'friend_list_screen.dart';
import '../../providers/notification_provider.dart';
import 'notification_screen.dart';
import '../../widgets/social_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with Cover Image & Avatar
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A0533),  // Deep charcoal purple
                        AppTheme.primaryViolet.withAlpha(220),
                        const Color(0xFF0D1B2A),  // Dark navy
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 50,
                  right: 16,
                  child: Row(
                    children: [
                      Consumer<NotificationProvider>(
                        builder: (context, notificationProvider, _) => Stack(
                          clipBehavior: Clip.none,
                          children: [
                            IconButton(
                              icon: const FaIcon(FontAwesomeIcons.solidBell, color: Colors.white, size: 20),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (context) => const NotificationScreen()),
                                );
                              },
                            ),
                            if (notificationProvider.unreadCount > 0)
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    '${notificationProvider.unreadCount}',
                                    style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.gear, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
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
                      backgroundImage: user?['profile_picture'] != null
                          ? CachedNetworkImageProvider(ApiService.getMediaUrl(user!['profile_picture'])!)
                          : null,
                      child: user?['profile_picture'] == null
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
              user?['username'] ?? 'User',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SocialBadge(gravity: (user?['social_gravity'] ?? 1.0).toDouble()),
                const SizedBox(width: 8),
                if ((user?['streak_count'] ?? 0) > 0)
                  StreakBadge(count: user?['streak_count']),
              ],
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(
                    user?['gender'] == 'M' ? FontAwesomeIcons.mars : FontAwesomeIcons.venus,
                    size: 14,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    user?['gender'] == 'M' ? 'Male' : user?['gender'] == 'F' ? 'Female' : '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('Age', '${user?['age'] ?? '?'}'),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const FriendListScreen()),
                      );
                    },
                    child: _buildStatItem('Connections', (user?['connections_count'] ?? 0).toString()),
                  ),
                  _buildStatItem('Posts', (user?['posts_count'] ?? 0).toString()),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Interests Chips
            if (user?['interests'] != null && (user!['interests'] as List).isNotEmpty)
              Wrap(
                spacing: 8,
                children: (user['interests'] as List)
                    .map<Widget>((interest) => _buildInterestChip(interest['name'] ?? ''))
                    .toList(),
              )
            else
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No interests added yet',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),

            const SizedBox(height: 32),

            // Settings/Edit Profile Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppTheme.primaryViolet),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  foregroundColor: AppTheme.primaryViolet,
                ),
                child: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),

            // Moments Grid
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Moments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  FutureBuilder<List<dynamic>>(
                    future: ApiService.getUserPosts(),
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
                          final String? imageUrl = post['thumbnail'] ?? post['image'];
                          
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
                                    child: imageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: ApiService.getMediaUrl(imageUrl)!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                                            errorWidget: (_, __, ___) => const Center(child: FaIcon(FontAwesomeIcons.image, color: Colors.white30)),
                                          )
                                        : Center(child: FaIcon(post['video'] != null ? FontAwesomeIcons.video : FontAwesomeIcons.pencil, size: 20, color: AppTheme.textSecondary)),
                                  ),
                                  if (post['video'] != null)
                                    const Center(
                                      child: FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 24),
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

            // Collaborative Moments
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Collaborative Moments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 16),
                  FutureBuilder<List<dynamic>>(
                    future: ApiService.getCollaborativePosts(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text('No shared moments yet', style: TextStyle(color: AppTheme.textSecondary)),
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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CollaborativePostDetailScreen(post: post),
                                ),
                              );
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    height: double.infinity,
                                    color: AppTheme.surfaceGray,
                                    child: (post['thumbnail'] ?? post['image']) != null
                                        ? CachedNetworkImage(
                                            imageUrl: ApiService.getMediaUrl(post['thumbnail'] ?? post['image'])!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(color: Colors.grey[200]),
                                            errorWidget: (_, __, ___) => const Center(child: FaIcon(FontAwesomeIcons.image, color: Colors.white30)),
                                          )
                                        : Center(child: FaIcon(post['video'] != null ? FontAwesomeIcons.video : FontAwesomeIcons.pencil, size: 20, color: AppTheme.textSecondary)),
                                  ),
                                  if (post['video'] != null)
                                    const Center(
                                      child: FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 24),
                                    ),
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

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildInterestChip(String label) {
    return Chip(
      label: Text(label),
      backgroundColor: AppTheme.surfaceGray,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
