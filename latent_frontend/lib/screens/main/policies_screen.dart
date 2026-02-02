import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Policies & Terms'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to Latent Network',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryViolet),
            ),
            const SizedBox(height: 8),
            const Text(
              'by Impiy Technologies',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 32),
            _buildPolicyItem(
              'Age Requirement',
              'We only allow users above 13 years of age. By using this platform, you certify that you meet this requirement.',
            ),
            _buildPolicyItem(
              'Content Standards',
              'Latent Network maintains a strictly professional and social environment. No pornography or sexually explicit content is allowed under any circumstances. Accounts violating this will be permanently banned.',
            ),
            _buildPolicyItem(
              'Neutral Platform',
              'To ensure a focused social experience, no political campaigns or partisan propaganda are permitted on the platform.',
            ),
            _buildPolicyItem(
              'Our Mission',
              'We just want people to have that real connection. Latent Network is designed to facilitate local, meaningful social discovery.',
            ),
            const SizedBox(height: 48),
            const Center(
              child: Text(
                'Help us keep the community safe and connected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicyItem(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(fontSize: 15, height: 1.5, color: AppTheme.textMain),
          ),
        ],
      ),
    );
  }
}
