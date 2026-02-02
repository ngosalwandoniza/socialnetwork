import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController(); // For backup code
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  int _step = 1; // 1: Username, 2: Choose Method, 3: Inputs, 4: Success
  String _method = ''; // 'code' or 'social'
  bool _isLoading = false;
  String? _error;
  String? _socialToken;

  void _nextStep() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_step == 1) {
        // Just move to step 2 to choose method
        setState(() => _step = 2);
      } else if (_step == 2) {
        if (_method == 'social') {
          // Initiate social recovery
          final result = await ApiService.initiateRecovery(_usernameController.text);
          setState(() {
            _socialToken = result['token'];
            _step = 3;
          });
        } else {
          setState(() => _step = 3);
        }
      } else if (_step == 3) {
        // Final reset
        if (_passwordController.text != _confirmPasswordController.text) {
          throw Exception('Passwords do not match');
        }

        if (_method == 'code') {
          await ApiService.resetPasswordWithCode(
            username: _usernameController.text,
            recoveryCode: _codeController.text,
            newPassword: _passwordController.text,
          );
        } else {
          await ApiService.resetPasswordWithToken(
            username: _usernameController.text,
            token: _socialToken!, // The 6-digit token they initiated with
            newPassword: _passwordController.text,
          );
        }
        setState(() => _step = 4);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Account Recovery')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (_step == 1) _buildStep1(),
            if (_step == 2) _buildStep2(),
            if (_step == 3) _buildStep3(),
            if (_step == 4) _buildStep4(),
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            
            const SizedBox(height: 48),
            if (_step < 4) 
              ElevatedButton(
                onPressed: _isLoading ? null : _nextStep,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_step == 3 ? 'Reset Password' : 'Continue'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      children: [
        const FaIcon(FontAwesomeIcons.circleQuestion, size: 64, color: AppTheme.primaryViolet),
        const SizedBox(height: 24),
        const Text('Who are you?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Enter your username to begin recovery', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(hintText: 'Username'),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        const Text('Choose Recovery Method', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: _method == 'code' ? AppTheme.primaryViolet.withOpacity(0.1) : AppTheme.surfaceGray.withOpacity(0.3),
          leading: const FaIcon(FontAwesomeIcons.key),
          title: const Text('Use Backup Code'),
          subtitle: const Text('Enter one of your 8-digit recovery codes'),
          onTap: () => setState(() => _method = 'code'),
        ),
        const SizedBox(height: 16),
        ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: _method == 'social' ? AppTheme.primaryViolet.withOpacity(0.1) : AppTheme.surfaceGray.withOpacity(0.3),
          leading: const FaIcon(FontAwesomeIcons.usersViewfinder),
          title: const Text('Social Recovery'),
          subtitle: const Text('Ask your trusted friends to vouch for you'),
          onTap: () => setState(() => _method = 'social'),
        ),
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      children: [
        if (_method == 'social') ...[
          const Text('Vouch Requested', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryViolet.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryViolet.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                const Text('Your Recovery Token:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 8),
                Text(
                  _socialToken ?? '------',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppTheme.primaryViolet),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Give this code to your designated Guardians. They must enter it in their settings to approve your reset.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14),
          ),
        ] else ...[
          const Text('Enter Backup Code', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(hintText: '8-Digit Code'),
            maxLength: 8,
          ),
        ],
        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 32),
        const Text('New Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'New Password'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'Confirm Password'),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      children: [
        const FaIcon(FontAwesomeIcons.circleCheck, size: 64, color: Colors.green),
        const SizedBox(height: 24),
        const Text('Success!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        const Text('Your password has been reset. You can now login with your new credentials.', textAlign: TextAlign.center),
        const SizedBox(height: 40),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to Login'),
        ),
      ],
    );
  }
}
