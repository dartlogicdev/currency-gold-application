// API Konfiguration
class Config {
  // Environment Detection
  static const bool isDevelopment = bool.fromEnvironment(
    'DEVELOPMENT',
    defaultValue: false,
  );

  // Server URL - automatisch je nach Environment
  // Für Production: Ersetze mit deiner Cloud-URL
  static const String _devApiBaseUrl = 'http://192.168.178.42:3000';
  static const String _prodApiBaseUrl =
      'https://currency-gold-application.onrender.com'; // Beispiel

  static String get apiBaseUrl =>
      isDevelopment ? _devApiBaseUrl : _prodApiBaseUrl;

  // Endpoints
  static String get ratesEndpoint => '$apiBaseUrl/rates';
  static String get goldEndpoint => '$apiBaseUrl/gold';
  static String goldHistoryEndpoint(int days) =>
      '$apiBaseUrl/gold/history?days=$days';
  static String get healthEndpoint => '$apiBaseUrl/health';

  // Cache-Einstellungen für die App
  static const Duration appCacheDuration = Duration(minutes: 5);
  static const Duration goldCacheDuration = Duration(minutes: 10);

  // Retry-Einstellungen
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  // Timeout-Einstellungen
  static const Duration requestTimeout = Duration(seconds: 10);
}

// Beispiel-Nutzung in anderen Dateien:
// 
// Development Mode (Standard):
//   flutter run
//
// Production Mode:
//   flutter run --dart-define=DEVELOPMENT=false
//   flutter build apk --dart-define=DEVELOPMENT=false

