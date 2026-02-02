import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../services/api_service.dart';
import '../main/profile_detail_screen.dart';

class CollaborativePostDetailScreen extends StatefulWidget {
  final Map<String, dynamic> post;

  const CollaborativePostDetailScreen({super.key, required this.post});

  @override
  State<CollaborativePostDetailScreen> createState() => _CollaborativePostDetailScreenState();
}

class _CollaborativePostDetailScreenState extends State<CollaborativePostDetailScreen> {
  final TextEditingController _contributionController = TextEditingController();
  File? _selectedImage;
  bool _isContributing = false;
  Map<String, dynamic>? _contributorsData;
  bool _isLoadingContributors = true;

  @override
  void initState() {
    super.initState();
    _loadContributors();
  }

  Future<void> _loadContributors() async {
    setState(() => _isLoadingContributors = true);
    try {
      final data = await context.read<FeedProvider>().getPostContributors(widget.post['id']);
      setState(() {
        _contributorsData = data;
        _isLoadingContributors = false;
      });
    } catch (e) {
      setState(() => _isLoadingContributors = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<void> _submitContribution() async {
    final text = _contributionController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    setState(() => _isContributing = true);
    try {
      await context.read<FeedProvider>().contributeToPost(
        widget.post['id'],
        text: text,
        image: _selectedImage,
      );
      _contributionController.clear();
      setState(() {
        _selectedImage = null;
        _isContributing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contribution added!')),
      );
      // We might need to refresh the post state here if we want to show it immediately
    } catch (e) {
      setState(() => _isContributing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to contribute: $e')),
      );
    }
  }

  void _showInviteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Invite Contributors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                  const SizedBox(height: 8),
                  const Text('Select friends to add to this moment', style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 24),
                  Expanded(
                    child: FutureBuilder<List<dynamic>>(
                      future: ApiService.getConnections(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        }
                        final connections = snapshot.data ?? [];
                        final friends = connections.where((c) => c['status'] == 'CONNECTED').toList();
                        
                        if (friends.isEmpty) {
                          return const Center(child: Text('No connected friends to invite'));
                        }

                        return ListView.builder(
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final connection = friends[index];
                            final currentUser = context.read<AuthProvider>().currentUser;
                            final friend = connection['sender']['id'] == currentUser?['id'] 
                                ? connection['receiver'] 
                                : connection['sender'];
                            
                            final isAlreadyContributor = _contributorsData?['contributors']?.any((c) => c['id'] == friend['id']) ?? false;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: friend['profile_picture'] != null 
                                    ? NetworkImage(ApiService.getMediaUrl(friend['profile_picture'])!) 
                                    : null,
                                child: friend['profile_picture'] == null ? const FaIcon(FontAwesomeIcons.user, size: 14) : null,
                              ),
                              title: Text(friend['username'] ?? 'Friend'),
                              trailing: isAlreadyContributor 
                                ? const Text('Added', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryViolet,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    onPressed: () async {
                                      try {
                                        await context.read<FeedProvider>().inviteContributor(widget.post['id'], friend['id']);
                                        await _loadContributors();
                                        if (mounted) Navigator.pop(context);
                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                          SnackBar(content: Text('Invited ${friend['username']}')),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    },
                                    child: const Text('Invite'),
                                  ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthProvider>().currentUser;
    final isAuthor = currentUser != null && currentUser['id'] == widget.post['author'];
    final isContributor = _contributorsData?['contributors']?.any((c) => c['id'] == currentUser?['id']) ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Collaborative Moment'),
        actions: [
          if (isAuthor)
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.userPlus, size: 20),
              onPressed: _showInviteSheet,
              tooltip: 'Invite Friends',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original Post Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: widget.post['author_pic'] != null 
                            ? NetworkImage(ApiService.getMediaUrl(widget.post['author_pic'])!) 
                            : null,
                        child: widget.post['author_pic'] == null ? const FaIcon(FontAwesomeIcons.user) : null,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.post['author_name'] ?? 'Author', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text(widget.post['post_type'] == 'PERSISTENT' ? 'Persistent' : 'Ephemeral', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.post['image'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        ApiService.getMediaUrl(widget.post['image'])!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(widget.post['content_text'] ?? '', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 32),
                  
                  // Contributors Section
                  const Text('Contributors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 12),
                  if (_isLoadingContributors)
                    const LinearProgressIndicator()
                  else if (_contributorsData != null && _contributorsData!['contributors'].isNotEmpty)
                    SizedBox(
                      height: 60,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _contributorsData!['contributors'].length,
                        itemBuilder: (context, index) {
                          final contributor = _contributorsData!['contributors'][index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: Tooltip(
                              message: contributor['username'],
                              child: CircleAvatar(
                                radius: 25,
                                backgroundImage: contributor['profile_picture'] != null 
                                    ? NetworkImage(ApiService.getMediaUrl(contributor['profile_picture'])!) 
                                    : null,
                                child: contributor['profile_picture'] == null ? Text(contributor['username'][0].toUpperCase()) : null,
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    const Text('No contributors yet', style: TextStyle(color: AppTheme.textSecondary)),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          
          // Contribution Input Area
          if (isAuthor || isContributor)
            Container(
              padding: EdgeInsets.only(
                left: 24, 
                right: 24, 
                top: 16, 
                bottom: MediaQuery.of(context).padding.bottom + 16
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, -2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedImage != null)
                    Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_selectedImage!, height: 100, width: 100, fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: IconButton(
                            icon: const FaIcon(FontAwesomeIcons.circleXmark, color: Colors.red, size: 20),
                            onPressed: () => setState(() => _selectedImage = null),
                          ),
                        ),
                      ],
                    ),
                  Row(
                    children: [
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.image, color: AppTheme.primaryViolet),
                        onPressed: _pickImage,
                      ),
                      Expanded(
                        child: TextField(
                          controller: _contributionController,
                          decoration: InputDecoration(
                            hintText: 'Add to this moment...',
                            filled: true,
                            fillColor: AppTheme.surfaceGray,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isContributing 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : IconButton(
                            icon: const FaIcon(FontAwesomeIcons.solidPaperPlane, color: AppTheme.primaryViolet),
                            onPressed: _submitContribution,
                          ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
