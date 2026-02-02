import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/notification_provider.dart';
import '../../providers/connection_provider.dart';
import '../../services/api_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
      context.read<ConnectionProvider>().loadPendingConnections();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<NotificationProvider>().loadNotifications();
          await context.read<ConnectionProvider>().loadPendingConnections();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Connection Requests'),
              _buildPendingRequests(),
              _buildSectionTitle('Recent Activity'),
              _buildNotifications(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textMain),
      ),
    );
  }

  Widget _buildPendingRequests() {
    return Consumer<ConnectionProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.pendingConnections.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        
        if (provider.pendingConnections.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No pending requests', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.pendingConnections.length,
          itemBuilder: (context, index) {
            final request = provider.pendingConnections[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.surfaceGray,
                child: const FaIcon(FontAwesomeIcons.user, size: 16, color: AppTheme.primaryViolet),
              ),
              title: Text(request['sender_name'] ?? 'Someone', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('wants to connect with you'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => provider.acceptRequest(request['id']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => provider.rejectRequest(request['id']),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotifications() {
    return Consumer<NotificationProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.notifications.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
        }
        
        if (provider.notifications.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No notifications yet', style: TextStyle(color: AppTheme.textSecondary)),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.notifications.length,
          itemBuilder: (context, index) {
            final notification = provider.notifications[index];
            final bool isRead = notification['is_read'] ?? false;

            return Container(
              color: isRead ? Colors.transparent : AppTheme.primaryViolet.withAlpha(15),
              child: ListTile(
                onTap: () {
                  if (!isRead) {
                    provider.markAsRead(notification['id']);
                  }
                },
                leading: _buildNotificationIcon(notification['notification_type']),
                title: Text(notification['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text(notification['body'] ?? ''),
                trailing: Text(
                  _formatTimestamp(notification['created_at']),
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotificationIcon(String? type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'MESSAGE':
        icon = FontAwesomeIcons.solidComment;
        color = Colors.blue;
        break;
      case 'CONNECTION_REQUEST':
        icon = FontAwesomeIcons.userPlus;
        color = Colors.orange;
        break;
      case 'CONNECTION_ACCEPTED':
        icon = FontAwesomeIcons.userCheck;
        color = Colors.green;
        break;
      default:
        icon = FontAwesomeIcons.bell;
        color = AppTheme.primaryViolet;
    }

    return CircleAvatar(
      radius: 18,
      backgroundColor: color.withAlpha(30),
      child: FaIcon(icon, size: 14, color: color),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);
      
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${dt.day}/${dt.month}';
    } catch (e) {
      return '';
    }
  }
}
