class AppConfig {
  // API Configuration
  // For production builds, use: flutter build --dart-define=API_BASE_URL=https://api.yourapp.com
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://98.93.41.22/api',
  );
  
  static const String mediaBaseUrl = String.fromEnvironment(
    'MEDIA_BASE_URL', 
    defaultValue: 'http://98.93.41.22',
  );
  
  // Feature Flags
  static const bool enablePushNotifications = true;
  static const bool showSocialGravity = true;
  
  // Environment detection
  static bool get isProduction => baseUrl.contains('https://');
}
