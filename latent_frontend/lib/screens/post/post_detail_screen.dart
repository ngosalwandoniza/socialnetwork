import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../post/post_video_player.dart';

class PostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late bool _isLiked;
  late int _likesCount;
  late int _commentsCount;
  bool _isLiking = false;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post['is_liked'] ?? false;
    _likesCount = widget.post['likes_count'] ?? 0;
    _commentsCount = widget.post['comments_count'] ?? 0;
  }

  Future<void> _toggleLike() async {
    if (_isLiking) return;
    setState(() => _isLiking = true);
    
    try {
      final result = await ApiService.likePost(widget.post['id']);
      setState(() {
        _isLiked = result['liked'] ?? !_isLiked;
        if (_isLiked) {
          _likesCount++;
        } else {
          _likesCount--;
        }
        _isLiking = false;
      });
    } catch (e) {
      setState(() => _isLiking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showCommentSheet() {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Comment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Write something...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isEmpty) return;
                  Navigator.pop(context);
                  try {
                    await ApiService.addComment(widget.post['id'], text);
                    setState(() {
                      _commentsCount++;
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comment added!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to add comment: $e')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryViolet,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Post Comment', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.post['image'] != null;
    final hasVideo = widget.post['video'] != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Moment Details'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textMain,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: widget.post['author_pic'] != null
                        ? NetworkImage(ApiService.getMediaUrl(widget.post['author_pic'])!)
                        : null,
                    child: widget.post['author_pic'] == null ? const FaIcon(FontAwesomeIcons.user, size: 16) : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post['author_name'] ?? 'User',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        widget.post['post_type'] ?? 'EPHEMERAL',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Media
            if (hasVideo)
              AspectRatio(
                aspectRatio: 9 / 16, // TikTok style
                child: PostVideoPlayer(videoUrl: ApiService.getMediaUrl(widget.post['video'])!),
              )
            else if (hasImage)
              Image.network(
                ApiService.getMediaUrl(widget.post['image'])!,
                width: double.infinity,
                fit: BoxFit.cover,
              ),

            // Text Content
            if (widget.post['content_text'] != null && widget.post['content_text'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  widget.post['content_text'],
                  style: const TextStyle(fontSize: 16),
                ),
              ),

            // Stats
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                   GestureDetector(
                     onTap: _toggleLike,
                     child: FaIcon(
                        _isLiked ? FontAwesomeIcons.solidHeart : FontAwesomeIcons.heart, 
                        size: 20, 
                        color: _isLiked ? Colors.red : AppTheme.textSecondary
                      ),
                   ),
                   const SizedBox(width: 6),
                   Text('$_likesCount', style: TextStyle(color: AppTheme.textSecondary, fontWeight: _isLiked ? FontWeight.bold : FontWeight.normal)),
                   const SizedBox(width: 20),
                   GestureDetector(
                     onTap: _showCommentSheet,
                     child: FaIcon(FontAwesomeIcons.comment, size: 20, color: AppTheme.textSecondary),
                   ),
                   const SizedBox(width: 6),
                   Text('$_commentsCount', style: TextStyle(color: AppTheme.textSecondary)),
                ],
              ),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
