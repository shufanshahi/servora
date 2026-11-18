import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/network/media_url.dart';

void main() {
  const emulator = 'http://10.0.2.2:3000';

  group('resolveMediaUrl', () {
    test('points a localhost picture at the API host the app uses', () {
      expect(
        resolveMediaUrl(
          'http://localhost:3000/images/services/a.jpg',
          emulator,
        ),
        'http://10.0.2.2:3000/images/services/a.jpg',
      );
      expect(
        resolveMediaUrl('http://127.0.0.1:3000/images/a.jpg?v=2', emulator),
        'http://10.0.2.2:3000/images/a.jpg?v=2',
      );
    });

    test('takes the scheme and port from the API address too', () {
      expect(
        resolveMediaUrl(
          'http://localhost:3000/images/a.jpg',
          'https://api.example.com',
        ),
        'https://api.example.com/images/a.jpg',
      );
      expect(
        resolveMediaUrl(
          'http://localhost:3000/images/a.jpg',
          'http://192.168.1.20:8080',
        ),
        'http://192.168.1.20:8080/images/a.jpg',
      );
    });

    test('resolves a bare path against the API address', () {
      expect(
        resolveMediaUrl('/images/a.jpg', emulator),
        'http://10.0.2.2:3000/images/a.jpg',
      );
    });

    test('leaves pictures on a real host alone', () {
      const cdn = 'https://cdn.example.com/images/a.jpg';
      expect(resolveMediaUrl(cdn, emulator), cdn);
    });

    test('leaves localhost alone when the API is on localhost too', () {
      const url = 'http://localhost:3000/images/a.jpg';
      expect(resolveMediaUrl(url, 'http://localhost:3000'), url);
    });

    test('never throws on odd input', () {
      expect(resolveMediaUrl('  ', emulator), '');
      expect(resolveMediaUrl('not a url', emulator), 'not a url');
      expect(
        resolveMediaUrl('http://localhost/a.jpg', 'garbage'),
        'http://localhost/a.jpg',
      );
    });
  });
}
