import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/feed_provider.dart';
import '../../utils/media_helper.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  File? _selectedVideo;
  bool _isPosting = false;
  String _selectedPostType = 'EPHEMERAL';

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _selectedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    
    if (picked != null) {
      setState(() {
        _selectedVideo = File(picked.path);
        _selectedImage = null;
      });
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _selectedVideo = null;
      });
    }
  }

  Future<void> _createPost() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty && _selectedImage == null && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a caption, image or video')),
      );
      return;
    }

    if (caption.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Caption is too long (max 500 chars)')),
      );
      return;
    }

    if (_selectedImage != null && _selectedImage!.lengthSync() > 10 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image is too large (max 10MB)')),
      );
      return;
    }

    if (_selectedVideo != null && _selectedVideo!.lengthSync() > 50 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video is too large (max 50MB)')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      File? finalImage = _selectedImage;
      File? finalVideo = _selectedVideo;

      if (_selectedImage != null) {
        final compressed = await MediaHelper.compressImage(_selectedImage!);
        if (compressed != null) finalImage = compressed;
      } else if (_selectedVideo != null) {
        final compressed = await MediaHelper.compressVideo(_selectedVideo!);
        if (compressed != null) finalVideo = compressed;
      }

      await context.read<FeedProvider>().createPost(
        caption, 
        image: finalImage,
        video: finalVideo,
        postType: _selectedPostType,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Moment shared!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Moment'),
        leading: IconButton(
          icon: const FaIcon(FontAwesomeIcons.xmark, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isPosting)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                   Text(
                    _selectedVideo != null ? 'Uploading Video...' : 'Posting...', 
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)
                  ),
                  const SizedBox(width: 8),
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            )
          else
            TextButton(
              onPressed: _createPost,
              child: const Text('Post', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryViolet)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media Selector
            GestureDetector(
              onTap: () => _showMediaOptions(),
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGray,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.surfaceGray, width: 2),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(_selectedImage!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null && _selectedVideo == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(FontAwesomeIcons.camera, size: 48, color: AppTheme.textSecondary),
                          SizedBox(height: 16),
                          Text('Tap to add photo or video', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      )
                    : Stack(
                        children: [
                          if (_selectedVideo != null)
                             const Center(child: FaIcon(FontAwesomeIcons.video, size: 48, color: AppTheme.primaryViolet)),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _selectedImage = null;
                                _selectedVideo = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(127),
                                  shape: BoxShape.circle,
                                ),
                                child: const FaIcon(FontAwesomeIcons.xmark, size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),

            // Caption Input
            const Text('Caption', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _captionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'What\'s happening at this moment?',
                filled: true,
                fillColor: AppTheme.surfaceGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Post Type Toggle
            const Text('Post Visibility', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceGray,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  RadioListTile<String>(
                    value: 'EPHEMERAL',
                    groupValue: _selectedPostType,
                    onChanged: (val) => setState(() => _selectedPostType = val!),
                    title: const Text('Ephemeral (24 Hours)'),
                    subtitle: const Text('Disappears from the feed after 24 hours'),
                    activeColor: AppTheme.primaryViolet,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  RadioListTile<String>(
                    value: 'PERSISTENT',
                    groupValue: _selectedPostType,
                    onChanged: (val) => setState(() => _selectedPostType = val!),
                    title: const Text('Persistent (Show on Profile)'),
                    subtitle: const Text('Stays on your profile permanently'),
                    activeColor: AppTheme.primaryViolet,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Options
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.solidClock, size: 18, color: AppTheme.primaryViolet),
              title: const Text('Expiry Duration'),
              trailing: Text(_selectedPostType == 'EPHEMERAL' ? '24 Hours' : 'Never', style: const TextStyle(color: AppTheme.textSecondary)),
              onTap: () {},
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.locationDot, size: 18, color: AppTheme.primaryViolet),
              title: const Text('Add Location'),
              trailing: const Text('Current Location', style: TextStyle(color: AppTheme.textSecondary)),
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Add Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildMediaOption(FontAwesomeIcons.camera, 'Photo', _takePhoto),
                  _buildMediaOption(FontAwesomeIcons.image, 'Gallery', _pickImage),
                  _buildMediaOption(FontAwesomeIcons.video, 'Video', _pickVideo),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(this.context);
        onTap();
      },
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppTheme.surfaceGray,
            child: FaIcon(icon, color: AppTheme.primaryViolet, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
