import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/discovery_provider.dart';
import '../../services/api_service.dart';
import '../main/discovery_grid.dart';

class SignupFlow extends StatefulWidget {
  const SignupFlow({super.key});

  @override
  State<SignupFlow> createState() => _SignupFlowState();
}

class _SignupFlowState extends State<SignupFlow> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps = 5;
  bool _isLoading = false;

  // Form Data
  String _username = '';
  String _password = '';
  String? _gender;
  int? _age;
  List<int> _selectedInterestIds = [];
  List<dynamic> _availableInterests = [];
  File? _profilePicture;
  String? _selectedAvatarAsset;

  // Controllers
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleSignup() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final success = await authProvider.register(
        username: _username,
        password: _password,
        gender: _gender!,
        age: _age!,
        interestIds: _selectedInterestIds,
        profilePicture: _profilePicture,
      );
      
      if (success && mounted) {
        // Try to get location and update
        await _updateLocation();
        
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DiscoveryGrid()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.error ?? 'Registration failed'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      await ApiService.updateLocation(position.latitude, position.longitude);
      
      if (mounted) {
        context.read<DiscoveryProvider>().loadSuggestions();
      }
    } catch (e) {
      // Location update failed, continue anyway
      debugPrint('Location update failed: $e');
    }
  }

  Future<void> _loadInterests() async {
    try {
      final interests = await ApiService.getInterests();
      setState(() {
        _availableInterests = interests;
      });
    } catch (e) {
      debugPrint('Failed to load interests: $e');
      // Fallback to minimal list if API fails
      setState(() {
        _availableInterests = [
          {'name': 'Gaming'}, {'name': 'Music'}, {'name': 'Tech'}
        ];
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInterests();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _currentStep > 0
            ? IconButton(
                icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 18),
                onPressed: _prevStep,
              )
            : IconButton(
                icon: const FaIcon(FontAwesomeIcons.xmark, size: 18),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / _totalSteps,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceGray,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryViolet),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        onPageChanged: (int index) {
          setState(() {
            _currentStep = index;
          });
        },
        children: [
          _buildIdentityStep(),
          _buildEssenceStep(),
          _buildAvatarStep(),
          _buildVibeStep(),
          _buildActivationStep(),
        ],
      ),
    );
  }

  Widget _buildIdentityStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pick a username',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'This is how people nearby will see you. Make it unique!',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _usernameController,
            onChanged: (value) => _username = value,
            decoration: const InputDecoration(
              hintText: 'e.g. creative_soul',
              prefixIcon: Padding(
                padding: EdgeInsets.all(14.0),
                child: FaIcon(FontAwesomeIcons.at, color: AppTheme.primaryViolet, size: 18),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            onChanged: (value) => _password = value,
            decoration: const InputDecoration(
              hintText: 'Password (min 6 characters)',
              prefixIcon: Padding(
                padding: EdgeInsets.all(14.0),
                child: FaIcon(FontAwesomeIcons.lock, color: AppTheme.primaryViolet, size: 18),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
              if (_username.length < 3) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Username must be at least 3 characters')),
                );
              } else if (!usernameRegex.hasMatch(_username)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Usernames can only contain letters, numbers, and underscores')),
                );
              } else if (_password.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password must be at least 6 characters')),
                );
              } else {
                _nextStep();
              }
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Continue'),
                SizedBox(width: 8),
                FaIcon(FontAwesomeIcons.arrowRight, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEssenceStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us more',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Help us find the right social gravity for you.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderChip('Male', 'M'),
              const SizedBox(width: 12),
              _buildGenderChip('Female', 'F'),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Age', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _ageController,
            keyboardType: TextInputType.number,
            onChanged: (value) => _age = int.tryParse(value),
            decoration: const InputDecoration(
              hintText: 'e.g. 21',
              prefixIcon: Padding(
                padding: EdgeInsets.all(14.0),
                child: FaIcon(FontAwesomeIcons.calendar, color: AppTheme.primaryViolet, size: 18),
              ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_gender != null && _age != null && _age! >= 13 && _age! < 100) {
                _nextStep();
              }
            },
            child: const Text('Looking good'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label, String value) {
    bool isSelected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryViolet : AppTheme.surfaceGray,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: AppTheme.primaryViolet, width: 2) : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textMain,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStep() {
    final List<String> femaleAvatars = [
      'assets/avatars/female.png',
      'assets/avatars/female1.png',
      'assets/avatars/female2.png',
      'assets/avatars/female3.png',
      'assets/avatars/female4.png',
      'assets/avatars/female5.png',
      'assets/avatars/female6.png',
      'assets/avatars/female7.png',
      'assets/avatars/female8.png',
    ];

    final List<String> maleAvatars = [
      'assets/avatars/bull-terrier_2829735.png',
      'assets/avatars/camel_194622.png',
      'assets/avatars/face-mask_17533761.png',
      'assets/avatars/leopard-face_18281628.png',
      'assets/avatars/money_8913342.png',
      'assets/avatars/raccoon_6359703.png',
      'assets/avatars/smile_16063993.png',
      'assets/avatars/wolf_2144137.png',
    ];

    final List<String> avatars = _gender == 'F' ? femaleAvatars : maleAvatars;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who are you?',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Select an avatar or upload your own.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: AppTheme.surfaceGray,
                  backgroundImage: _profilePicture != null 
                    ? FileImage(_profilePicture!) 
                    : (_selectedAvatarAsset != null ? AssetImage(_selectedAvatarAsset!) as ImageProvider : null),
                  child: (_profilePicture == null && _selectedAvatarAsset == null)
                    ? const FaIcon(FontAwesomeIcons.camera, size: 30, color: AppTheme.primaryViolet)
                    : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: avatars.length,
              itemBuilder: (context, index) {
                final assetPath = avatars[index];
                final isSelected = _selectedAvatarAsset == assetPath;
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedAvatarAsset = assetPath;
                      _profilePicture = null;
                    });
                    // Copy asset to file for upload
                    final byteData = await rootBundle.load(assetPath);
                    final file = File('${(await getTemporaryDirectory()).path}/${assetPath.split('/').last}');
                    await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
                    setState(() {
                      _profilePicture = file;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: AppTheme.primaryViolet, width: 3) : null,
                    ),
                    child: CircleAvatar(
                      backgroundImage: AssetImage(assetPath),
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_profilePicture != null) _nextStep();
            },
            child: const Text('I\'m Ready'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profilePicture = File(image.path);
        _selectedAvatarAsset = null;
      });
    }
  }

  Widget _buildVibeStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your vibe?',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
          ),
          const SizedBox(height: 12),
          Text(
            'Pick 3-7 things you love. We use these for matching.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: SingleChildScrollView(
              child: _availableInterests.isEmpty 
                ? const Center(child: CircularProgressIndicator())
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _availableInterests.map((interest) {
                      final name = interest['name'];
                      final id = interest['id'];
                      bool isSelected = _selectedInterestIds.contains(id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedInterestIds.remove(id);
                            } else if (_selectedInterestIds.length < 7) {
                              _selectedInterestIds.add(id);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryViolet : AppTheme.surfaceGray,
                            borderRadius: BorderRadius.circular(30),
                            border: isSelected ? Border.all(color: AppTheme.primaryViolet, width: 2) : null,
                          ),
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textMain,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
            ),
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              if (_selectedInterestIds.length >= 3) _nextStep();
            },
            child: const Text('Perfect'),
          ),
        ],
      ),
    );
  }

  Widget _buildActivationStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FaIcon(FontAwesomeIcons.locationDot, size: 80, color: AppTheme.primaryViolet),
          const SizedBox(height: 40),
          Text(
            'Almost there!',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 32),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Latent needs your location to show who\'s nearby. Your exact coordinates are never shared.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 60),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSignup,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Enter the Room'),
                      SizedBox(width: 12),
                      FaIcon(FontAwesomeIcons.doorOpen, size: 20),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
