import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/features/auth/data/auth_repository.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

/// What a login or registration form needs to show.
class AuthFormState {
  const AuthFormState({
    this.isSubmitting = false,
    this.failure,
    this.fieldErrors = const {},
  });

  /// A request is in flight: the submit button is disabled and shows progress.
  final bool isSubmitting;

  /// A problem that is not about one field (wrong password, offline, server error).
  final AppFailure? failure;

  /// Server messages for individual fields, keyed by field name (email, password...).
  final Map<String, String> fieldErrors;
}

/// Shared behaviour of the login and registration controllers.
abstract class AuthFormController extends Notifier<AuthFormState> {
  @override
  AuthFormState build() => const AuthFormState();

  /// Runs [action], signs the user in on success, and turns any failure into state.
  /// A second call while one is running is ignored, so double taps send one request.
  Future<void> submit(Future<AuthResult> Function() action) async {
    if (state.isSubmitting) return;
    state = const AuthFormState(isSubmitting: true);

    try {
      final result = await action();
      await ref.read(sessionProvider.notifier).signIn(result.toStoredSession());
      // The router now moves to Home and this screen goes away.
      if (ref.mounted) state = const AuthFormState();
    } on AppFailure catch (failure) {
      if (!ref.mounted) return;
      state = _stateFor(failure);
    }
  }

  /// Forgets the server's message for one field once the user edits it.
  void clearFieldError(String field) {
    if (!state.fieldErrors.containsKey(field)) return;
    state = AuthFormState(
      failure: state.failure,
      fieldErrors: {...state.fieldErrors}..remove(field),
    );
  }

  AuthFormState _stateFor(AppFailure failure) {
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      return AuthFormState(fieldErrors: failure.fieldErrors);
    }
    if (failure is ConflictFailure && failure.code == 'EMAIL_TAKEN') {
      return AuthFormState(fieldErrors: {'email': failure.userMessage});
    }
    return AuthFormState(failure: failure);
  }
}

class LoginController extends AuthFormController {
  Future<void> login({required String email, required String password}) {
    return submit(
      () => ref
          .read(authRepositoryProvider)
          .login(email: email.trim(), password: password),
    );
  }
}

class RegisterController extends AuthFormController {
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) {
    return submit(
      () => ref
          .read(authRepositoryProvider)
          .register(name: name.trim(), email: email.trim(), password: password),
    );
  }
}

final loginControllerProvider =
    NotifierProvider.autoDispose<LoginController, AuthFormState>(
      LoginController.new,
    );

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, AuthFormState>(
      RegisterController.new,
    );
