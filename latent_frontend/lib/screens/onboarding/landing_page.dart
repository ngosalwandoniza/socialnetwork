import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'signup_flow.dart';
import 'forgot_password_screen.dart';
import '../main/discovery_grid.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _formKey = GlobalKey<FormState>();
  String _username = '';
  String _password = '';
  bool _isPasswordVisible = false;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.login(_username, _password);
      
      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DiscoveryGrid()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              authProvider.error ?? 'Login failed',
              style: GoogleFonts.robotoMono(fontSize: 12),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo at top
              Text(
                'Latent',
                style: GoogleFonts.outfit(
                  fontSize: 60,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryViolet,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Proximity-first social space',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 60),

              // Login Form
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: 'Username',
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(14.0),
                          child: FaIcon(FontAwesomeIcons.user, size: 18, color: AppTheme.textSecondary),
                        ),
                      ),
                      onChanged: (value) => _username = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter your username' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        prefixIcon: const Padding(
                          padding: EdgeInsets.all(14.0),
                          child: FaIcon(FontAwesomeIcons.lock, size: 18, color: AppTheme.textSecondary),
                        ),
                        suffixIcon: IconButton(
                          icon: FaIcon(
                            _isPasswordVisible ? FontAwesomeIcons.eyeSlash : FontAwesomeIcons.eye,
                            size: 16,
                            color: AppTheme.textSecondary,
                          ),
                          onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),
                      onChanged: (value) => _password = value,
                      validator: (value) => value == null || value.isEmpty ? 'Enter your password' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
                          );
                        },
                        child: const Text('Forgot Password?', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: authProvider.isLoading ? null : _handleLogin,
                      child: authProvider.isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Login'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppTheme.surfaceGray, thickness: 2)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: AppTheme.surfaceGray, thickness: 2)),
                ],
              ),

              const SizedBox(height: 40),

              // Signup Section
              Text(
                "Don't have an account?",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SignupFlow()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: AppTheme.primaryViolet),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  foregroundColor: AppTheme.primaryViolet,
                ),
                child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 48),
              const Text(
                'from impiy technology',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
