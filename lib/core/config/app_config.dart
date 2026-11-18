/// Build-time configuration, injected with `--dart-define`.
///
/// Example: `flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000`
///
/// Nothing secret belongs here: the app ships to users' devices, so any value in
/// the build can be extracted. AI and database credentials live only on the backend.
class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  /// The Android emulator reaches the host machine at 10.0.2.2, so this default
  /// works out of the box with the backend running locally on port 3000.
  static const String defaultApiBaseUrl = 'http://10.0.2.2:3000';

  /// Builds the config from `--dart-define` values, falling back to
  /// [defaultApiBaseUrl].
  factory AppConfig.fromEnvironment() {
    const raw = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultApiBaseUrl,
    );
    return AppConfig.parse(raw);
  }

  /// Normalises a raw base URL: trims whitespace and trailing slashes so paths
  /// can be appended safely. Falls back to the default for blank input.
  factory AppConfig.parse(String raw) {
    var url = raw.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return AppConfig(apiBaseUrl: url.isEmpty ? defaultApiBaseUrl : url);
  }

  /// Base URL of the Servora API, without a trailing slash.
  final String apiBaseUrl;
}
