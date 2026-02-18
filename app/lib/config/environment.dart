class Environment {
  // API configuration
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://claudiasrv.duckdns.org',
  );

  // Environment
  static const String env = String.fromEnvironment(
    'ENV',
    defaultValue: 'development',
  );

  static bool get isDevelopment => env == 'development';
  static bool get isProduction => env == 'production';

  static const bool disableInteractiveGoogleMap = bool.fromEnvironment(
    'DISABLE_INTERACTIVE_GOOGLE_MAP',
    defaultValue: false,
  );
}
