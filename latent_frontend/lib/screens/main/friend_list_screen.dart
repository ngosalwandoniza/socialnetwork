import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/connection_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import 'profile_detail_screen.dart';
import '../chat/chat_detail_screen.dart';

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
      context.read<ConnectionProvider>().loadConnections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Connections', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: Consumer<ConnectionProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.connections.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredList = provider.connections.where((c) {
                  final name = c['sender_name'] ?? c['receiver_name'] ?? '';
                  return name.toLowerCase().contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FaIcon(FontAwesomeIcons.userGroup, size: 64, color: AppTheme.textSecondary.withAlpha(50)),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No connections yet' : 'No matches found',
                          style: const TextStyle(fontSize: 18, color: AppTheme.textSecondary),
                        ),
                        if (_searchQuery.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                            child: Text(
                              'Discover people nearby and connect with them!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.textSecondary.withAlpha(150)),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final connection = filteredList[index];
                    final authProvider = context.read<AuthProvider>();
                    final currentUserId = authProvider.currentUser?['id'];
                    
                    final bool isSenderMe = connection['sender'] == currentUserId;
                    final int partnerId = isSenderMe ? connection['receiver'] : connection['sender'];
                    final String partnerName = isSenderMe ? (connection['receiver_name'] ?? 'User') : (connection['sender_name'] ?? 'User');
                    
                    return _buildFriendCard(partnerName, partnerId, connection);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Search connections...',
          prefixIcon: const Icon(Icons.search, color: AppTheme.primaryViolet),
          filled: true,
          fillColor: AppTheme.surfaceGray,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildFriendCard(String name, int partnerId, Map<String, dynamic> connection) {
    final authProvider = context.read<AuthProvider>();
    final currentUserId = authProvider.currentUser?['id'];
    final bool isSenderMe = connection['sender'] == currentUserId;
    final String? partnerPic = isSenderMe ? connection['receiver_pic'] : connection['sender_pic'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: AppTheme.surfaceGray.withAlpha(50),
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ProfileDetailScreen(profile: {'id': partnerId, 'username': name, 'profile_picture': partnerPic}),
            ),
          );
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryViolet.withAlpha(30),
          backgroundImage: partnerPic != null ? NetworkImage(ApiService.getMediaUrl(partnerPic)!) : null,
          child: partnerPic == null 
              ? const FaIcon(FontAwesomeIcons.user, size: 20, color: AppTheme.primaryViolet)
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Connected'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const FaIcon(FontAwesomeIcons.solidComment, color: AppTheme.primaryViolet, size: 20),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ChatDetailScreen(
                      userId: partnerId,
                      userName: name,
                      userProfilePicture: partnerPic,
                    ),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(connection, partnerId, name),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(Map<String, dynamic> connection, int partnerId, String name) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('View Profile'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ProfileDetailScreen(profile: {'id': partnerId, 'username': name}),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_remove, color: Colors.red),
            title: const Text('Disconnect', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDisconnect(partnerId, name);
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _confirmDisconnect(int partnerId, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect?'),
        content: Text('Are you sure you want to disconnect from $name?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ConnectionProvider>().disconnect(partnerId);
            },
            child: const Text('Disconnect', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
