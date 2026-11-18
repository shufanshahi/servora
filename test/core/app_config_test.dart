import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses the emulator-friendly default when nothing is defined', () {
      // Run without --dart-define: the default applies.
      const defined = String.fromEnvironment('API_BASE_URL');
      final config = AppConfig.fromEnvironment();
      if (defined.isEmpty) {
        expect(config.apiBaseUrl, AppConfig.defaultApiBaseUrl);
        expect(config.apiBaseUrl, 'http://10.0.2.2:3000');
      } else {
        expect(config.apiBaseUrl, AppConfig.parse(defined).apiBaseUrl);
      }
    });

    test('honours an overridden URL', () {
      final config = AppConfig.parse('https://servora.example.com');
      expect(config.apiBaseUrl, 'https://servora.example.com');
    });

    test('strips whitespace and trailing slashes', () {
      expect(
        AppConfig.parse('  http://x.test:3000//  ').apiBaseUrl,
        'http://x.test:3000',
      );
    });

    test('falls back to the default for blank input', () {
      expect(AppConfig.parse('   ').apiBaseUrl, AppConfig.defaultApiBaseUrl);
      expect(AppConfig.parse('/').apiBaseUrl, AppConfig.defaultApiBaseUrl);
    });
  });
}
