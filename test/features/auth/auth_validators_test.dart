import 'package:flutter_test/flutter_test.dart';
import 'package:servora/features/auth/domain/auth_validators.dart';

// The vectors below are the same ones the backend's registration tests use
// (backend/test/auth.register.test.ts), so both sides are held to one set of rules.
void main() {
  group('name', () {
    test('accepts ordinary names, trimmed', () {
      expect(AuthValidators.name('Ada Lovelace'), isNull);
      expect(AuthValidators.name('  Ada  '), isNull);
      expect(AuthValidators.name('x' * 100), isNull);
    });

    test('rejects empty or whitespace-only names', () {
      expect(AuthValidators.name(null), 'Name is required');
      expect(AuthValidators.name(''), 'Name is required');
      expect(AuthValidators.name('   '), 'Name is required');
    });

    test('rejects names over 100 characters', () {
      expect(
        AuthValidators.name('x' * 101),
        'Name must be at most 100 characters',
      );
    });
  });

  group('email', () {
    test('accepts valid addresses, ignoring surrounding spaces', () {
      for (final ok in [
        'ada@example.com',
        '  ADA@Example.COM ',
        'first.last+tag@sub.example.co.uk',
        "o'brien@example.org",
        'a_b-c@example.io',
      ]) {
        expect(AuthValidators.email(ok), isNull, reason: ok);
      }
    });

    test('rejects the malformed addresses the API rejects', () {
      for (final bad in [
        'not-an-email',
        'a@b',
        '@example.com',
        'a b@example.com',
      ]) {
        expect(
          AuthValidators.email(bad),
          'Enter a valid email address',
          reason: bad,
        );
      }
    });

    test('rejects leading dots, doubled dots and one-letter TLDs', () {
      for (final bad in ['.a@example.com', 'a..b@example.com', 'a@example.c']) {
        expect(AuthValidators.email(bad), isNotNull, reason: bad);
      }
    });

    test('requires a value', () {
      expect(AuthValidators.email(''), 'Email is required');
      expect(AuthValidators.email(null), 'Email is required');
      expect(AuthValidators.email('   '), 'Email is required');
    });

    test('rejects addresses over 254 characters', () {
      final long = '${'a' * 250}@example.com';
      expect(AuthValidators.email(long), 'Email is too long');
    });
  });

  group('newPassword', () {
    test('accepts 8+ characters with a letter and a number', () {
      expect(AuthValidators.newPassword('abcdef1x'), isNull);
      expect(AuthValidators.newPassword('Sup3rSecret'), isNull);
      expect(AuthValidators.newPassword('1234567a'), isNull);
    });

    test('too short', () {
      expect(
        AuthValidators.newPassword('Ab1'),
        'Password must be at least 8 characters',
      );
      expect(
        AuthValidators.newPassword('abcdef1'),
        'Password must be at least 8 characters',
      );
    });

    test('needs a number', () {
      expect(
        AuthValidators.newPassword('OnlyLetters'),
        'Password must contain a number',
      );
    });

    test('needs a letter', () {
      expect(
        AuthValidators.newPassword('1234567890'),
        'Password must contain a letter',
      );
    });

    test('rejects more than 72 bytes (counting bytes, not characters)', () {
      expect(
        AuthValidators.newPassword('A1${'x' * 80}'),
        'Password must be at most 72 bytes',
      );
      expect(AuthValidators.newPassword('A1${'x' * 70}'), isNull);
      // 40 two-byte characters + "A1" = 82 bytes although only 42 characters.
      expect(
        AuthValidators.newPassword('A1${'é' * 40}'),
        'Password must be at most 72 bytes',
      );
    });

    test('required', () {
      expect(AuthValidators.newPassword(''), 'Password is required');
      expect(AuthValidators.newPassword(null), 'Password is required');
    });
  });

  group('existingPassword (login)', () {
    test('only requires that something was typed', () {
      expect(AuthValidators.existingPassword('a'), isNull);
      expect(AuthValidators.existingPassword('weak'), isNull);
      expect(AuthValidators.existingPassword(''), 'Password is required');
      expect(AuthValidators.existingPassword(null), 'Password is required');
    });
  });
}
