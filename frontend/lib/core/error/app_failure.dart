/// The single error type the UI ever sees. Repositories throw an [AppFailure];
/// widgets render [userMessage]. Raw exceptions, stack traces and HTTP bodies never
/// reach the user.
sealed class AppFailure implements Exception {
  const AppFailure({this.code});

  /// Machine-readable API error code (for example `EMAIL_TAKEN`), if the failure
  /// came from the API.
  final String? code;

  /// Friendly, safe-to-display text.
  String get userMessage;

  /// Whether trying the same request again could plausibly succeed.
  bool get isRetryable => false;

  @override
  String toString() => '$runtimeType(code: $code)';
}

/// The device is offline or the server is unreachable.
class NetworkFailure extends AppFailure {
  const NetworkFailure();

  @override
  String get userMessage =>
      "Can't reach the server. Check your internet connection and try again.";

  @override
  bool get isRetryable => true;
}

/// The server took too long to answer.
class TimeoutFailure extends AppFailure {
  const TimeoutFailure();

  @override
  String get userMessage =>
      'The server took too long to respond. Please try again.';

  @override
  bool get isRetryable => true;
}

/// Missing, invalid or expired credentials (HTTP 401).
class UnauthenticatedFailure extends AppFailure {
  const UnauthenticatedFailure({super.code, this.message});

  final String? message;

  @override
  String get userMessage =>
      message ?? 'Your session has expired. Please sign in again.';
}

/// Authenticated but not allowed (HTTP 403).
class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({super.code});

  @override
  String get userMessage => "You don't have permission to do that.";
}

/// Input failed server validation (HTTP 422). [fieldErrors] maps a field name to
/// its message so forms can show errors inline.
class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const {},
    this.message,
    super.code,
  });

  final Map<String, String> fieldErrors;
  final String? message;

  @override
  String get userMessage => message ?? 'Please check the highlighted fields.';
}

/// The request conflicts with current state (HTTP 409), for example an email that
/// is already registered or a slot that was just taken. [code] says which.
class ConflictFailure extends AppFailure {
  const ConflictFailure({required String super.code, this.message});

  final String? message;

  @override
  String get userMessage =>
      message ??
      'That action conflicts with the current state. Please refresh.';
}

/// The resource does not exist (HTTP 404).
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.code});

  @override
  String get userMessage => "We couldn't find what you were looking for.";
}

/// Too many requests (HTTP 429).
class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({super.code});

  @override
  String get userMessage =>
      "You're doing that too often. Please wait a moment and try again.";

  @override
  bool get isRetryable => true;
}

/// The server failed (HTTP 5xx).
class ServerFailure extends AppFailure {
  const ServerFailure({super.code});

  @override
  String get userMessage => 'Something went wrong. Please try again.';

  @override
  bool get isRetryable => true;
}

/// Anything unexpected, including malformed responses.
class UnknownFailure extends AppFailure {
  const UnknownFailure();

  @override
  String get userMessage => 'Something went wrong. Please try again.';

  @override
  bool get isRetryable => true;
}

/// Text to show for any error object. Anything that is not an [AppFailure] gets a
/// generic message so raw exceptions never leak into the UI.
String userMessageFor(Object error) {
  return error is AppFailure
      ? error.userMessage
      : const UnknownFailure().userMessage;
}
