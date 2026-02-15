import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../providers/discovery_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/chat_provider.dart';
import 'local_feed.dart';
import 'profile_screen.dart';
import '../chat/chat_list_screen.dart';
import '../post/create_post_screen.dart';
import '../chat/chat_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'profile_detail_screen.dart';
import 'notification_screen.dart';

class DiscoveryGrid extends StatefulWidget {
  const DiscoveryGrid({super.key});

  @override
  State<DiscoveryGrid> createState() => _DiscoveryGridState();
}

class _DiscoveryGridState extends State<DiscoveryGrid> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DiscoveryBody(),
    const LocalFeed(),
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const CreatePostScreen()),
          );
        },
        backgroundColor: AppTheme.primaryViolet,
        shape: const CircleBorder(),
        elevation: 4,
        child: const FaIcon(FontAwesomeIcons.plus, color: Colors.white),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, FontAwesomeIcons.compass, 'Discovery'),
            _buildNavItem(1, FontAwesomeIcons.bolt, 'Feed'),
            const SizedBox(width: 48), // Space for FAB
            _buildNavItem(2, FontAwesomeIcons.solidCommentDots, 'Chat', isChat: true),
            _buildNavItem(3, FontAwesomeIcons.solidUser, 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {bool isChat = false}) {
    bool isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              FaIcon(
                icon,
                color: isSelected ? AppTheme.primaryViolet : AppTheme.textSecondary,
                size: 20,
              ),
              if (isChat)
                Consumer<ChatProvider>(
                  builder: (context, provider, _) {
                    final count = provider.totalUnreadCount;
                    if (count == 0) return const SizedBox.shrink();
                    return Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$count',
                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryViolet : AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class DiscoveryBody extends StatefulWidget {
  const DiscoveryBody({super.key});

  @override
  State<DiscoveryBody> createState() => _DiscoveryBodyState();
}

class _DiscoveryBodyState extends State<DiscoveryBody> {
  String? _selectedInterest;
  List<dynamic> _allInterests = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DiscoveryProvider>().loadSuggestions();
      context.read<DiscoveryProvider>().loadFriends();
      _fetchInterests();
    });
  }

  Future<void> _fetchInterests() async {
    try {
      final interests = await ApiService.getInterests();
      setState(() {
        _allInterests = interests;
      });
    } catch (e) {
      debugPrint('Error fetching interests: $e');
    }
  }

  void _onInterestSelected(String? interest) {
    setState(() {
      _selectedInterest = interest;
    });
    context.read<DiscoveryProvider>().loadSuggestions(refresh: true, interest: interest);
  }

  @override
  Widget build(BuildContext context) {
    final discoveryProvider = context.watch<DiscoveryProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              discoveryProvider.currentLocation ?? 'Your Location',
              style: const TextStyle(fontSize: 18),
            ),
            Text(
              '${discoveryProvider.suggestions.length} people nearby',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) => Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.solidBell, size: 20),
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
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 18),
            onPressed: () => discoveryProvider.loadSuggestions(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Discovery',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
            ),
            const SizedBox(height: 12),
            _buildInterestChips(),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => discoveryProvider.loadSuggestions(refresh: true),
                color: AppTheme.primaryViolet,
                child: discoveryProvider.isLoading && discoveryProvider.suggestions.isEmpty
                    ? _buildShimmerGrid()
                    : discoveryProvider.suggestions.isEmpty
                      ? discoveryProvider.friends.isNotEmpty
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Text(
                                    'Nobody nearby, but here are your friends:',
                                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Expanded(
                                  child: GridView.builder(
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 0.6,
                                    ),
                                    itemCount: discoveryProvider.friends.length,
                                    itemBuilder: (context, index) {
                                      final conn = discoveryProvider.friends[index];
                                      final authProvider = context.read<AuthProvider>();
                                      final myId = authProvider.currentUser?['id'];
                                      
                                      // Extract the other profile from the connection
                                      final profile = conn['sender'] == myId ? {
                                        'id': conn['receiver'],
                                        'username': conn['receiver_name'],
                                        'profile_picture': conn['receiver_pic'],
                                        'connection_status': 'CONNECTED',
                                        'is_active': conn['receiver_is_active'] ?? false,
                                      } : {
                                        'id': conn['sender'],
                                        'username': conn['sender_name'],
                                        'profile_picture': conn['sender_pic'],
                                        'connection_status': 'CONNECTED',
                                        'is_active': conn['sender_is_active'] ?? false,
                                      };

                                      return _buildProfileCard(context, profile, discoveryProvider);
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const FaIcon(FontAwesomeIcons.userGroup, size: 48, color: AppTheme.textSecondary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No one nearby yet',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Move to a different location or check back later',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                      : GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.6,
                          ),
                          itemCount: discoveryProvider.suggestions.length,
                          itemBuilder: (context, index) {
                            final profile = discoveryProvider.suggestions[index];
                            return _buildProfileCard(context, profile, discoveryProvider);
                          },
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterestChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _allInterests.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            final isSelected = _selectedInterest == null;
            return ChoiceChip(
              label: const Text('All'),
              selected: isSelected,
              onSelected: (selected) => _onInterestSelected(null),
              backgroundColor: Colors.transparent,
              selectedColor: AppTheme.primaryViolet,
              labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textMain),
            );
          }
          
          final interest = _allInterests[index - 1];
          final name = interest['name'];
          final isSelected = _selectedInterest == name;
          
          return ChoiceChip(
            label: Text(name),
            selected: isSelected,
            onSelected: (selected) => _onInterestSelected(selected ? name : null),
            backgroundColor: Colors.transparent,
            selectedColor: AppTheme.primaryViolet,
            labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textMain),
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceGray,
      highlightColor: Colors.white.withAlpha(100),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.6,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileCard(BuildContext context, Map<String, dynamic> profile, DiscoveryProvider provider) {
    final interests = (profile['interests'] as List<dynamic>?)?.take(1).map((i) => i['name']).join(', ') ?? '';
    final latestPost = profile['latest_post'];
    final profilePic = profile['profile_picture'];
    final hasLatestPostMedia = latestPost != null && (latestPost['image'] != null || latestPost['video'] != null);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProfileDetailScreen(profile: profile),
          ),
        );
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Main Media (Latest Post or Fallback)
            Positioned.fill(
              child: Container(
                color: AppTheme.surfaceGray,
                child: hasLatestPostMedia
                    ? CachedNetworkImage(
                        imageUrl: ApiService.getMediaUrl(latestPost['image'] ?? latestPost['video'])!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.white24)),
                        errorWidget: (_, __, ___) => const Center(child: FaIcon(FontAwesomeIcons.image, color: Colors.white30)),
                      )
                                ),
                              ],
                            ),
                          ),
                        ),
              ),
            ),

            // Bottom Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withAlpha(25),
                      Colors.black.withAlpha(200),
                    ],
                    stops: const [0.5, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Profile Info Overlay
            Positioned(
              left: 12,
              bottom: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundImage: profilePic != null ? CachedNetworkImageProvider(ApiService.getMediaUrl(profilePic)!) : null,
                          child: profilePic == null ? const FaIcon(FontAwesomeIcons.user, size: 10) : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          profile['username'] ?? 'Latent User',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${profile['age'] ?? '—'}${interests.isNotEmpty ? ' • $interests' : ''}',
                          style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (profile['smart_snippet'] != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryViolet.withAlpha(150),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            profile['smart_snippet'],
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  if ((profile['mutual_connections_count'] ?? 0) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          _buildMutualAvatars(profile['mutual_friend_pics'] ?? []),
                          const SizedBox(width: 6),
                          Text(
                            '${profile['mutual_connections_count']} Mutuals',
                            style: const TextStyle(color: AppTheme.accentPink, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            // Live Indicator
            if (profile['is_active'] == true)
              Positioned(
                top: 12,
                left: 12,
                child: _PulsingIndicator(),
              ),

            // Connection Status Action FAB-like
            Positioned(
              top: 12,
              right: 12,
              child: GestureDetector(
                onTap: () {
                  final status = profile['connection_status'] ?? 'NONE';
                  if (status == 'NONE') {
                    provider.sendConnectionRequest(profile['id']);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connection request sent!'), duration: Duration(seconds: 2)),
                    );
                  } else if (status == 'CONNECTED') {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ChatDetailScreen(
                          userId: profile['id'],
                          userName: profile['username'] ?? 'User',
                          userProfilePicture: profile['profile_picture'],
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: _buildConnectionIcon(profile['connection_status'] ?? 'NONE'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionIcon(String status) {
    switch (status) {
      case 'PENDING':
        return const FaIcon(FontAwesomeIcons.clock, size: 14, color: Colors.orange);
      case 'CONNECTED':
        return const FaIcon(FontAwesomeIcons.solidComment, size: 14, color: AppTheme.primaryViolet);
      default:
        return const FaIcon(FontAwesomeIcons.userPlus, size: 14, color: AppTheme.primaryViolet);
    }
  }

  Widget _buildMutualAvatars(List<dynamic> pics) {
    if (pics.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 16,
      width: (pics.length.clamp(1, 3) * 12.0) + 4.0,
      child: Stack(
        children: List.generate(
          pics.length.clamp(0, 3),
          (index) => Positioned(
            left: index * 12.0,
            child: CircleAvatar(
              radius: 8,
              backgroundColor: Colors.white,
              child: CircleAvatar(
                radius: 7,
                backgroundImage: CachedNetworkImageProvider(ApiService.getMediaUrl(pics[index])!),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: Colors.green, blurRadius: 4, spreadRadius: 1),
        ]),
      ),
    );
  }
}
class PremiumDiscoveryPlaceholder extends StatelessWidget {
  final String username;
  const PremiumDiscoveryPlaceholder({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // Slate 900
      ),
      child: Stack(
        children: [
          CustomPaint(
            painter: MeshPainter(),
            size: Size.infinite,
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withAlpha(30), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryViolet.withAlpha(40),
                        blurRadius: 30,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.solidUserCircle,
                    size: 60,
                    color: Colors.white.withAlpha(40),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  username.characters.firstOrNull?.toUpperCase() ?? 'L',
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w200,
                    color: Colors.white.withAlpha(20),
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MeshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    
    // Abstract mesh blobs
    final blobs = [
      {'pos': Offset(size.width * 0.2, size.height * 0.3), 'size': size.width * 0.6, 'color': AppTheme.primaryViolet.withAlpha(40)},
      {'pos': Offset(size.width * 0.8, size.height * 0.7), 'size': size.width * 0.5, 'color': AppTheme.accentPink.withAlpha(30)},
      {'pos': Offset(size.width * 0.5, size.height * 0.5), 'size': size.width * 0.8, 'color': const Color(0xFF4F46E5).withAlpha(20)},
    ];

    for (var blob in blobs) {
      paint.shader = RadialGradient(
        colors: [blob['color'] as Color, (blob['color'] as Color).withAlpha(0)],
      ).createShader(Rect.fromCircle(center: blob['pos'] as Offset, radius: blob['size'] as double));
      canvas.drawCircle(blob['pos'] as Offset, blob['size'] as double, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
