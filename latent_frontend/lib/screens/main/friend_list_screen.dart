import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'profile_detail_screen.dart';
import '../chat/chat_detail_screen.dart';
import 'package:intl/intl.dart';

class FriendListScreen extends StatefulWidget {
  const FriendListScreen({super.key});

  @override
  State<FriendListScreen> createState() => _FriendListScreenState();
}

class _FriendListScreenState extends State<FriendListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Messages', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 28, letterSpacing: -1)),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.circleQuestion, size: 20, color: AppTheme.textSecondary),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ChatProvider>().loadConversations(refresh: true),
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: Consumer<ChatProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading && provider.conversations.isEmpty) {
                    return _buildLoadingState();
                  }

                  final filteredList = provider.conversations.where((c) {
                    final name = c['partner_name'] ?? '';
                    return name.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  if (filteredList.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final chat = filteredList[index];
                      return _buildChatTile(chat);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        height: 80,
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGray.withAlpha(100),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: AppTheme.primaryViolet.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const FaIcon(FontAwesomeIcons.solidCommentDots, size: 48, color: AppTheme.primaryViolet),
          ),
          const SizedBox(height: 24),
          const Text(
            'No conversations yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Message your friends to start chatting!',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceGray.withAlpha(150),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: const InputDecoration(
            hintText: 'Search chats...',
            prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> chat) {
    final String partnerName = chat['partner_name'] ?? 'User';
    final String? partnerPic = chat['partner_pic'];
    final String lastMsg = chat['last_message'] ?? '';
    final int unreadCount = chat['unread_count'] ?? 0;
    final String? timestamp = chat['last_timestamp'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                userId: chat['partner_id'],
                userName: partnerName,
                userProfilePicture: partnerPic,
              ),
            ),
          ).then((_) => context.read<ChatProvider>().loadConversations());
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.surfaceGray),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(5),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.primaryViolet.withAlpha(40), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppTheme.surfaceGray,
                      backgroundImage: partnerPic != null ? NetworkImage(ApiService.getMediaUrl(partnerPic)!) : null,
                      child: partnerPic == null 
                          ? const FaIcon(FontAwesomeIcons.solidUser, size: 24, color: AppTheme.textSecondary)
                          : null,
                    ),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppTheme.accentPink,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          partnerName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5),
                        ),
                        if (timestamp != null)
                          Text(
                            _formatChatTime(timestamp),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMsg.isEmpty ? 'Start a conversation' : lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unreadCount > 0 ? AppTheme.textMain : AppTheme.textSecondary,
                        fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatChatTime(String timestamp) {
    final DateTime dt = DateTime.parse(timestamp).toLocal();
    final DateTime now = DateTime.now();
    
    if (now.difference(dt).inDays == 0) {
      return DateFormat.Hm().format(dt);
    } else if (now.difference(dt).inDays < 7) {
      return DateFormat.E().format(dt);
    } else {
      return DateFormat.yMMMd().format(dt);
    }
  }
}
