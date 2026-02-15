import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/media_helper.dart';

class ChatDetailScreen extends StatefulWidget {
  final int userId;
  final String userName;
  final String? userProfilePicture;
  
  const ChatDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userProfilePicture,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  File? _selectedImage;
  File? _selectedVideo;
  bool _isSending = false;

  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onMessageChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.loadMessages(widget.userId);
      // currentChatUserId is set by loadMessages
    });
  }

  void _onMessageChanged() {
    if (_messageController.text.isNotEmpty) {
      _sendTypingIndicator();
    }
  }

  void _sendTypingIndicator() {
    if (_typingTimer?.isActive ?? false) return;
    
    // Send typing signal
    context.read<ChatProvider>().sendTyping();
    
    // Debounce: don't send another typing signal for 3 seconds
    _typingTimer = Timer(const Duration(seconds: 3), () {});
  }

  void _onScroll() {
    // Load older messages when scrolled near the top
    if (_scrollController.position.pixels < 100 && _scrollController.position.pixels >= 0) {
      context.read<ChatProvider>().loadMoreMessages();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _messageController.removeListener(_onMessageChanged);
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    // Clear current chat synchronously before disposal
    Provider.of<ChatProvider>(context, listen: false).clearCurrentChat();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final picker = ImagePicker();
    final pickedFile = isVideo 
      ? await picker.pickVideo(source: source)
      : await picker.pickImage(source: source);
    
    if (pickedFile != null) {
      setState(() {
        if (isVideo) {
          _selectedVideo = File(pickedFile.path);
          _selectedImage = null;
        } else {
          _selectedImage = File(pickedFile.path);
          _selectedVideo = null;
        }
      });
    }
  }

  void _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty && _selectedImage == null && _selectedVideo == null) return;
    
    setState(() => _isSending = false); // Change to false since we use optimistic UI
    
    final image = _selectedImage;
    final video = _selectedVideo;
    
    _messageController.clear();
    setState(() {
      _selectedImage = null;
      _selectedVideo = null;
    });

    // Optimistic UI: Add a placeholder message locally via provider
    await context.read<ChatProvider>().sendMessage(
      widget.userId, 
      content: content.isNotEmpty ? content : null,
      image: image,
      video: video,
      isOptimistic: true,
    );

    // Scroll to bottom
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final authProvider = context.watch<AuthProvider>();
    final messages = chatProvider.currentMessages;
    final currentUserId = authProvider.currentUser?['id'];
    final isTyping = chatProvider.isUserTyping(widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.surfaceGray,
              backgroundImage: widget.userProfilePicture != null 
                  ? CachedNetworkImageProvider(ApiService.getMediaUrl(widget.userProfilePicture!)!) 
                  : null,
              child: widget.userProfilePicture == null 
                  ? const FaIcon(FontAwesomeIcons.user, size: 14, color: AppTheme.primaryViolet) 
                  : null,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.userName, style: const TextStyle(fontSize: 16)),
                if (isTyping)
                  const Text(
                    'Typing...',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primaryViolet,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowsRotate, size: 16),
            onPressed: () => chatProvider.loadMessages(widget.userId),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const FaIcon(FontAwesomeIcons.comments, size: 48, color: AppTheme.textSecondary),
                            const SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation!',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMe = message['sender'] == currentUserId;
                          return _buildMessageBubble(
                            message['content'], 
                            isMe, 
                            message['timestamp'],
                            image: message['image'],
                            video: message['video'],
                            thumbnail: message['thumbnail'],
                            isSending: message['is_sending'] ?? false,
                          );
                        },
                      ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String? text, bool isMe, String? timestamp, {String? image, String? video, String? thumbnail, bool isSending = false}) {
    final bubbleColor = isMe ? AppTheme.primaryViolet : Colors.white;
    final textColor = isMe ? Colors.white : AppTheme.textMain;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isMe ? 25 : 15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image != null)
                    _buildMediaPreview(image, isVideo: false),
                  if (video != null)
                    _buildMediaPreview(video, isVideo: true, thumbnail: thumbnail),
                  if (text != null && text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Text(
                        text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMe) const SizedBox(width: 4),
                Text(
                  _formatTime(timestamp ?? DateTime.now().toIso8601String()),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  isSending
                      ? const FaIcon(FontAwesomeIcons.clock, size: 9, color: AppTheme.textSecondary)
                      : const FaIcon(FontAwesomeIcons.checkDouble, size: 10, color: AppTheme.primaryViolet),
                ],
                if (isMe) const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaPreview(String path, {required bool isVideo, String? thumbnail}) {
    return GestureDetector(
      onTap: () {
        // Implement full screen preview if needed
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        width: double.infinity,
        color: AppTheme.surfaceGray,
        child: Stack(
          alignment: Alignment.center,
          children: [
            path.startsWith('/') 
              ? Image.file(File(isVideo ? (thumbnail ?? path) : path), fit: BoxFit.cover, width: double.infinity)
              : CachedNetworkImage(
                  imageUrl: ApiService.getMediaUrl(isVideo ? (thumbnail ?? path) : path)!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  placeholder: (context, url) => Container(color: Colors.black12, child: const Center(child: CircularProgressIndicator())),
                  errorWidget: (context, url, error) => const Center(child: Icon(Icons.error_outline)),
                ),
            if (isVideo)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withAlpha(80), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedImage != null || _selectedVideo != null)
          Container(
            padding: const EdgeInsets.all(12),
            color: AppTheme.surfaceGray.withAlpha(100),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _selectedImage != null 
                    ? Image.file(_selectedImage!, height: 60, width: 60, fit: BoxFit.cover)
                    : Container(
                        height: 60, width: 60, 
                        color: AppTheme.primaryViolet, 
                        child: const Center(child: FaIcon(FontAwesomeIcons.video, color: Colors.white))
                      ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedImage != null ? 'Image selected' : 'Video selected',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.circleXmark, size: 20, color: AppTheme.textSecondary),
                  onPressed: () => setState(() {
                    _selectedImage = null;
                    _selectedVideo = null;
                  }),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showMediaPicker,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGray,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(FontAwesomeIcons.circlePlus, size: 20, color: AppTheme.primaryViolet),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceGray,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSending 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.primaryViolet, AppTheme.accentPink],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.solidPaperPlane, color: Colors.white, size: 18),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.image, color: AppTheme.primaryViolet),
              title: const Text('Send Image'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, false);
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.video, color: AppTheme.primaryViolet),
              title: const Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, true);
              },
            ),
            ListTile(
              leading: const FaIcon(FontAwesomeIcons.camera, color: AppTheme.primaryViolet),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, false);
              },
            ),
          ],
        ),
      ),
    );
  }
}
