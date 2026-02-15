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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppTheme.primaryViolet : AppTheme.surfaceGray,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (image != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: image.startsWith('/') // Local path
                    ? Image.file(File(image), height: 200, width: double.infinity, fit: BoxFit.cover)
                    : CachedNetworkImage(
                        imageUrl: ApiService.getMediaUrl(image)!,
                        placeholder: (context, url) => const SizedBox(height: 200, width: double.infinity, child: Center(child: CircularProgressIndicator())),
                        errorWidget: (context, url, error) => const FaIcon(FontAwesomeIcons.circleExclamation),
                        fit: BoxFit.cover,
                      ),
                ),
              ),
            if (video != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (thumbnail != null)
                        thumbnail.startsWith('/') // Local path
                          ? Image.file(File(thumbnail), height: 200, width: double.infinity, fit: BoxFit.cover)
                          : CachedNetworkImage(
                              imageUrl: ApiService.getMediaUrl(thumbnail)!,
                              placeholder: (context, url) => const SizedBox(height: 200, width: double.infinity, child: Center(child: CircularProgressIndicator())),
                              errorWidget: (context, url, error) => const FaIcon(FontAwesomeIcons.circleExclamation),
                              fit: BoxFit.cover,
                            )
                      else
                        Container(
                          height: 200,
                          width: double.infinity,
                          color: Colors.black26,
                          child: const Center(child: FaIcon(FontAwesomeIcons.video, size: 32, color: Colors.white24)),
                        ),
                      // Play Icon Overlay
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: const FaIcon(FontAwesomeIcons.play, size: 20, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            if (text != null && text.isNotEmpty)
              Text(
                text,
                style: TextStyle(color: isMe ? Colors.white : AppTheme.textMain),
              ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(timestamp),
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white.withAlpha(180) : AppTheme.textSecondary,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      isSending
                        ? const FaIcon(FontAwesomeIcons.clock, size: 8, color: Colors.white70)
                        : const FaIcon(FontAwesomeIcons.check, size: 8, color: Colors.white),
                    ],
                  ],
                ),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, -2)),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const FaIcon(FontAwesomeIcons.circlePlus, color: AppTheme.primaryViolet, size: 24),
                  onPressed: _showMediaPicker,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _messageController,
                    textInputAction: TextInputAction.send,
                    onFieldSubmitted: (_) => _sendMessage(),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppTheme.surfaceGray,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _isSending 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : GestureDetector(
                      onTap: _sendMessage,
                      child: const FaIcon(FontAwesomeIcons.solidPaperPlane, color: AppTheme.primaryViolet, size: 22),
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
