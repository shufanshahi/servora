import 'package:flutter_test/flutter_test.dart';
import 'package:servora/core/error/app_failure.dart';

void main() {
  group('AppFailure.userMessage', () {
    test('network failure says the connection failed', () {
      expect(const NetworkFailure().userMessage, contains("Can't reach"));
      expect(const NetworkFailure().isRetryable, isTrue);
    });

    test('timeout failure is retryable and readable', () {
      expect(const TimeoutFailure().userMessage, contains('too long'));
      expect(const TimeoutFailure().isRetryable, isTrue);
    });

    test('unauthenticated defaults to a session-expired message', () {
      expect(
        const UnauthenticatedFailure().userMessage,
        'Your session has expired. Please sign in again.',
      );
    });

    test('unauthenticated can carry the server message (wrong password)', () {
      const failure = UnauthenticatedFailure(
        code: 'INVALID_CREDENTIALS',
        message: 'Incorrect email or password',
      );
      expect(failure.userMessage, 'Incorrect email or password');
      expect(failure.code, 'INVALID_CREDENTIALS');
    });

    test('validation exposes per-field errors and a default message', () {
      const failure = ValidationFailure(
        fieldErrors: {'email': 'Invalid email'},
      );
      expect(failure.fieldErrors['email'], 'Invalid email');
      expect(failure.userMessage, 'Please check the highlighted fields.');
    });

    test('conflict carries its code and prefers the server message', () {
      const failure = ConflictFailure(
        code: 'SLOT_UNAVAILABLE',
        message: 'That time was just taken',
      );
      expect(failure.code, 'SLOT_UNAVAILABLE');
      expect(failure.userMessage, 'That time was just taken');
      expect(
        const ConflictFailure(code: 'X').userMessage,
        contains('conflicts'),
      );
    });

    test('not found, forbidden and rate limited have friendly text', () {
      expect(const NotFoundFailure().userMessage, contains("couldn't find"));
      expect(const ForbiddenFailure().userMessage, contains('permission'));
      expect(const RateLimitedFailure().userMessage, contains('too often'));
      expect(const RateLimitedFailure().isRetryable, isTrue);
    });

    test('server and unknown failures are generic and retryable', () {
      expect(
        const ServerFailure().userMessage,
        'Something went wrong. Please try again.',
      );
      expect(
        const UnknownFailure().userMessage,
        'Something went wrong. Please try again.',
      );
      expect(const ServerFailure().isRetryable, isTrue);
    });

    test('non-retryable failures say so', () {
      expect(const UnauthenticatedFailure().isRetryable, isFalse);
      expect(const ValidationFailure().isRetryable, isFalse);
      expect(const NotFoundFailure().isRetryable, isFalse);
    });
  });

  group('userMessageFor', () {
    test('uses the failure message for an AppFailure', () {
      expect(userMessageFor(const NetworkFailure()), contains("Can't reach"));
    });

    test('hides raw exceptions behind a generic message', () {
      final message = userMessageFor(StateError('secret stack detail'));
      expect(message, 'Something went wrong. Please try again.');
      expect(message, isNot(contains('secret')));
    });
  });
}
