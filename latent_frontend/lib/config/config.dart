class AppConfig {
  // API Configuration
  // For production builds, use: flutter build --dart-define=API_BASE_URL=https://api.yourapp.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );
  
  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL', 
    defaultValue: 'http://127.0.0.1:8000',
  );
  
  // Feature Flags
  static const bool enablePushNotifications = true;
  static const bool showSocialGravity = true;
  
  // Environment detection
  static bool get isProduction => baseUrl.contains('https://');
}
