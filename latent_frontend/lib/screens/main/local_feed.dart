import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/feed_provider.dart';
import '../post/post_video_player.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/api_service.dart';
import 'profile_detail_screen.dart';
import '../post/collaborative_post_detail_screen.dart';
import '../../providers/notification_provider.dart';
import 'notification_screen.dart';

class LocalFeed extends StatefulWidget {
  const LocalFeed({super.key});

  @override
  State<LocalFeed> createState() => _LocalFeedState();
}

class _LocalFeedState extends State<LocalFeed> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Map<int, bool> _likedStates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 0) {
        context.read<FeedProvider>().loadFeed();
      } else {
        context.read<FeedProvider>().loadTrendingFeed();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedProvider>().loadFeed();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedProvider = context.watch<FeedProvider>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: feedProvider.isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : feedProvider.posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FaIcon(FontAwesomeIcons.camera, size: 48, color: Colors.white54),
                      const SizedBox(height: 16),
                      const Text(
                        'No moments yet',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share a moment!',
                        style: TextStyle(color: Colors.white.withAlpha(153)),
                      ),
                    ],
                  ),
                )
              : PageView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: feedProvider.posts.length,
                  itemBuilder: (context, index) {
                    return _buildTikTokFeedItem(context, feedProvider.posts[index], index, feedProvider);
                  },
                ),
    );
  }

  Widget _buildTikTokFeedItem(BuildContext context, Map<String, dynamic> post, int index, FeedProvider provider) {
    bool isLiked = post['is_liked'] ?? false;
    final hasImage = post['image'] != null;
    final hasVideo = post['video'] != null;

    return Stack(
      children: [
        // Media Background
        Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black,
          child: hasVideo
              ? PostVideoPlayer(videoUrl: post['video'])
              : hasImage
                  ? Image.network(
                      ApiService.getMediaUrl(post['image'])!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: FaIcon(
                          FontAwesomeIcons.image,
                          size: 80,
                          color: Colors.white.withAlpha(50),
                        ),
                      ),
                    )
                  : Center(
                      child: FaIcon(
                        FontAwesomeIcons.pencil,
                        size: 80,
                        color: Colors.white.withAlpha(50),
                      ),
                    ),
        ),

        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withAlpha(76),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withAlpha(127),
              ],
            ),
          ),
        ),

        // Content Positioned
        Positioned(
          left: 16,
          bottom: 24,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileDetailScreen(profile: {'id': post['author'], 'author_name': post['author_name'], 'author_pic': post['author_pic']}),
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppTheme.primaryViolet,
                          backgroundImage: post['author_pic'] != null 
                              ? NetworkImage(ApiService.getMediaUrl(post['author_pic'])!) 
                              : null,
                          child: post['author_pic'] == null ? const FaIcon(FontAwesomeIcons.user, size: 16, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          post['author_name'] ?? 'Anonymous',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
              Text(
                post['content_text'] ?? '',
                style: const TextStyle(color: Colors.white, fontSize: 16),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                   if (post['post_type'] == 'PERSISTENT')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryViolet.withAlpha(200),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('PERSISTENT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (post['post_type'] == 'PERSISTENT') const SizedBox(width: 8),
                  Text(
                    _formatTimestamp(post['created_at']),
                    style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right Side: Interaction buttons
        Positioned(
          right: 16,
          bottom: 40,
          child: Column(
            children: [
              _buildInteractionButton(
                isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart,
                '${post['likes_count'] ?? 0}',
                color: isLiked ? Colors.redAccent : Colors.white,
                onTap: () => provider.likePost(post['id']),
              ),
              const SizedBox(height: 20),
              _buildInteractionButton(
                FontAwesomeIcons.solidComment,
                '${post['comments_count'] ?? 0}',
                onTap: () => _showCommentsSheet(context, post),
              ),
              const SizedBox(height: 20),
              _buildInteractionButton(
                FontAwesomeIcons.peopleGroup,
                'Collaborate',
                color: post['is_collaborative'] == true ? AppTheme.primaryViolet : Colors.white,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CollaborativePostDetailScreen(post: post),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              _buildInteractionButton(
                FontAwesomeIcons.paperPlane,
                'Share',
                onTap: () {
                  final link = ApiService.getPostShareLink(post['id']);
                  Share.share('Check out this moment on Latent: $link');
                },
              ),
            ],
          ),
        ),

        // Top Bar
        Positioned(
          top: 50,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const FaIcon(FontAwesomeIcons.chevronLeft, color: Colors.white),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _tabController.animateTo(0),
                    child: Text(
                      'Local',
                      style: TextStyle(
                        color: provider.isTrending ? Colors.white.withAlpha(153) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: provider.isTrending ? TextDecoration.none : TextDecoration.underline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _tabController.animateTo(1),
                    child: Text(
                      'Trending',
                      style: TextStyle(
                        color: provider.isTrending ? Colors.white : Colors.white.withAlpha(153),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        decoration: provider.isTrending ? TextDecoration.underline : TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const FaIcon(FontAwesomeIcons.arrowsRotate, color: Colors.white),
                onPressed: () => provider.refresh(),
              ),
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
            ],
          ),
        ),
      ],
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return '';
    }
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: 250,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Text('Share Moment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildShareOption(FontAwesomeIcons.whatsapp, 'WhatsApp', Colors.green),
                  _buildShareOption(FontAwesomeIcons.instagram, 'Stories', Colors.purple),
                  _buildShareOption(FontAwesomeIcons.link, 'Copy Link', AppTheme.textSecondary),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShareOption(IconData icon, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.surfaceGray,
          child: FaIcon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showCommentsSheet(BuildContext context, Map<String, dynamic> post) {
    final TextEditingController commentController = TextEditingController();
    int? replyingToId;
    String? replyingToName;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  const Text('Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Divider(),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: context.read<FeedProvider>().getComments(post['id']),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const FaIcon(FontAwesomeIcons.comment, size: 32, color: AppTheme.textSecondary),
                                const SizedBox(height: 8),
                                Text('No comments yet', style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          );
                        }

                        // Organize comments: top-level and their replies
                        final comments = snapshot.data!;

                        return ListView.builder(
                          itemCount: comments.length,
                          itemBuilder: (context, index) {
                            final comment = comments[index];
                            final bool isReply = comment['parent'] != null;
                            final bool isLiked = comment['is_liked'] ?? false;

                            return Padding(
                              padding: EdgeInsets.only(left: isReply ? 40 : 0),
                              child: ListTile(
                                leading: CircleAvatar(
                                  radius: isReply ? 14 : 18,
                                  backgroundImage: comment['author_pic'] != null 
                                      ? NetworkImage(ApiService.getMediaUrl(comment['author_pic'])!) 
                                      : null,
                                  child: comment['author_pic'] == null ? const FaIcon(FontAwesomeIcons.user, size: 12) : null,
                                ),
                                title: Row(
                                  children: [
                                    Text(comment['author_name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Text(_formatTimestamp(comment['created_at']), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(comment['content'] ?? '', style: const TextStyle(color: Colors.black87, fontSize: 14)),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        GestureDetector(
                                          onTap: () async {
                                            await context.read<FeedProvider>().likeComment(comment['id']);
                                            setModalState(() {});
                                          },
                                          child: Text(
                                            isLiked ? 'Liked' : 'Like',
                                            style: TextStyle(
                                              fontSize: 12, 
                                              fontWeight: isLiked ? FontWeight.bold : FontWeight.normal,
                                              color: isLiked ? AppTheme.primaryViolet : AppTheme.textSecondary
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: () {
                                            setModalState(() {
                                              replyingToId = comment['id'];
                                              replyingToName = comment['author_name'];
                                            });
                                          },
                                          child: const Text('Reply', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                        ),
                                        if ((comment['likes_count'] ?? 0) > 0) ...[
                                          const SizedBox(width: 16),
                                          FaIcon(FontAwesomeIcons.solidHeart, size: 10, color: Colors.red.withAlpha(200)),
                                          const SizedBox(width: 4),
                                          Text('${comment['likes_count']}', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                        ]
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: isLiked 
                                  ? const FaIcon(FontAwesomeIcons.solidHeart, size: 14, color: Colors.red)
                                  : const FaIcon(FontAwesomeIcons.heart, size: 14, color: Colors.grey),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (replyingToId != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: AppTheme.surfaceGray,
                      child: Row(
                        children: [
                          Text('Replying to ', style: const TextStyle(fontSize: 12)),
                          Text(replyingToName ?? 'User', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => setModalState(() {
                              replyingToId = null;
                              replyingToName = null;
                            }),
                            child: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: commentController,
                            autofocus: replyingToId != null,
                            decoration: InputDecoration(
                              hintText: replyingToId != null ? 'Reply to $replyingToName...' : 'Add a comment...',
                              filled: true,
                              fillColor: AppTheme.surfaceGray,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.solidPaperPlane, color: AppTheme.primaryViolet, size: 20),
                          onPressed: () async {
                            if (commentController.text.isNotEmpty) {
                              await context.read<FeedProvider>().addComment(
                                post['id'], 
                                commentController.text,
                                parentId: replyingToId
                              );
                              commentController.clear();
                              setModalState(() {
                                replyingToId = null;
                                replyingToName = null;
                              });
                              setState(() {}); // Refresh parent list counts
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInteractionButton(IconData icon, String label, {Color color = Colors.white, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.black.withAlpha(51),
            child: FaIcon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
