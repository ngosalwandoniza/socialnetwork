import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../onboarding/landing_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'policies_screen.dart';
import 'recovery_setup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = false;

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LandingPage()),
          (route) => false,
        );
      }
    }
  }

  void _handleDeleteAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text('This action is permanent and cannot be undone. All your posts, connections, and messages will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Delete Permanently', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ApiService.deleteAccount();
        await context.read<AuthProvider>().logout();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const LandingPage()),
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete account: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _openWhatsAppHelp() async {
    final url = Uri.parse('https://wa.me/260763887732');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch WhatsApp')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
        children: [
          const SizedBox(height: 12),
          _buildSectionHeader('Account'),
          _buildSettingsTile(
            title: 'Logout',
            subtitle: 'Sign out of your account',
            icon: FontAwesomeIcons.rightFromBracket,
            iconColor: AppTheme.primaryViolet,
            onTap: _handleLogout,
          ),
          const Divider(indent: 70),
          _buildSettingsTile(
            title: 'Delete Account',
            subtitle: 'Permanently remove all your data',
            icon: FontAwesomeIcons.trashCan,
            iconColor: Colors.redAccent,
            onTap: _handleDeleteAccount,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader('Support'),
          _buildSettingsTile(
            title: 'Account Recovery',
            subtitle: 'Backup codes & Guardians',
            icon: FontAwesomeIcons.shieldHalved,
            iconColor: AppTheme.primaryViolet,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RecoverySetupScreen()),
              );
            },
          ),
          const Divider(indent: 70),
          _buildSettingsTile(
            title: 'Help Center',
            subtitle: 'Chat with us on WhatsApp',
            icon: FontAwesomeIcons.whatsapp,
            iconColor: Colors.green,
            onTap: _openWhatsAppHelp,
          ),
          const Divider(indent: 70),
          _buildSettingsTile(
            title: 'Terms of Service',
            subtitle: 'Read our policies',
            icon: FontAwesomeIcons.fileContract,
            iconColor: AppTheme.textSecondary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PoliciesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: FaIcon(icon, size: 18, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
