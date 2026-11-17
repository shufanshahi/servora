import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/format/formatters.dart';

void main() {
  group('formatPrice', () {
    test('whole amounts have no decimals', () {
      expect(formatPrice(65), r'$65');
      expect(formatPrice(0), r'$0');
      expect(formatPrice(100), r'$100');
    });

    test('other amounts show two decimals', () {
      expect(formatPrice(49.99), r'$49.99');
      expect(formatPrice(19.5), r'$19.50');
      expect(formatPrice(0.07), r'$0.07');
    });

    test('thousands are grouped', () {
      expect(formatPrice(1250), r'$1,250');
      expect(formatPrice(1250.5), r'$1,250.50');
    });
  });

  group('formatDuration', () {
    test('under an hour is in minutes', () {
      expect(formatDuration(30), '30 min');
      expect(formatDuration(45), '45 min');
      expect(formatDuration(59), '59 min');
    });

    test('whole hours drop the minutes', () {
      expect(formatDuration(60), '1 h');
      expect(formatDuration(120), '2 h');
    });

    test('hours and minutes combine', () {
      expect(formatDuration(90), '1 h 30 min');
      expect(formatDuration(135), '2 h 15 min');
    });

    test('covers every duration the catalogue uses', () {
      expect([30, 45, 60, 90].map(formatDuration), [
        '30 min',
        '45 min',
        '1 h',
        '1 h 30 min',
      ]);
    });
  });
}
