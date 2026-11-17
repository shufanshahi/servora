import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/features/profile/data/profile_repository.dart';

/// What the profile form needs to show.
class ProfileFormState {
  const ProfileFormState({
    this.isSaving = false,
    this.failure,
    this.fieldErrors = const {},
  });

  final bool isSaving;

  /// A problem that is not about one field (offline, server error).
  final AppFailure? failure;

  /// Server messages for single fields, keyed by field name (`name`, `phone`).
  final Map<String, String> fieldErrors;
}

/// Loads and saves the signed-in user's details. A save also updates the session's
/// cached user, so the new name appears everywhere it is shown and survives a restart.
class ProfileController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() => const ProfileFormState();

  /// Fetches the latest details and refreshes the session's copy. Failures are ignored:
  /// the cached details are still good enough to show.
  Future<void> load() async {
    try {
      final user = await ref.read(profileRepositoryProvider).me();
      if (!ref.mounted) return;
      await ref.read(sessionProvider.notifier).updateUser(user);
    } on AppFailure {
      // Keep showing what we have.
    }
  }

  /// Returns true when saved. On failure the reason is in [state] and nothing is lost.
  Future<bool> save({required String name, required String phone}) async {
    if (state.isSaving) return false; // a second tap while saving is ignored
    state = const ProfileFormState(isSaving: true);
    try {
      final user = await ref
          .read(profileRepositoryProvider)
          .update(name: name, phone: phone);
      await ref.read(sessionProvider.notifier).updateUser(user);
      if (ref.mounted) state = const ProfileFormState();
      return true;
    } on AppFailure catch (failure) {
      if (ref.mounted) state = _stateFor(failure);
      return false;
    }
  }

  void clearFieldError(String field) {
    if (!state.fieldErrors.containsKey(field)) return;
    state = ProfileFormState(
      failure: state.failure,
      fieldErrors: {...state.fieldErrors}..remove(field),
    );
  }

  static ProfileFormState _stateFor(AppFailure failure) {
    if (failure is ValidationFailure && failure.fieldErrors.isNotEmpty) {
      return ProfileFormState(fieldErrors: failure.fieldErrors);
    }
    return ProfileFormState(failure: failure);
  }
}

final profileControllerProvider =
    NotifierProvider.autoDispose<ProfileController, ProfileFormState>(
      ProfileController.new,
    );

/// The change-password form.
class PasswordController extends Notifier<ProfileFormState> {
  @override
  ProfileFormState build() => const ProfileFormState();

  /// Returns true when the password was changed.
  Future<bool> change({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (state.isSaving) return false;
    state = const ProfileFormState(isSaving: true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .changePassword(
            currentPassword: currentPassword,
            newPassword: newPassword,
          );
      if (ref.mounted) state = const ProfileFormState();
      return true;
    } on AppFailure catch (failure) {
      if (!ref.mounted) return false;
      if (failure is UnauthenticatedFailure &&
          failure.code == 'INVALID_CREDENTIALS') {
        // A typo in the current password is not a sign-out.
        state = const ProfileFormState(
          fieldErrors: {
            'currentPassword': 'Your current password is incorrect',
          },
        );
      } else if (failure is ValidationFailure &&
          failure.fieldErrors.isNotEmpty) {
        state = ProfileFormState(fieldErrors: failure.fieldErrors);
      } else {
        state = ProfileFormState(failure: failure);
      }
      return false;
    }
  }

  void clearFieldError(String field) {
    if (!state.fieldErrors.containsKey(field)) return;
    state = ProfileFormState(
      failure: state.failure,
      fieldErrors: {...state.fieldErrors}..remove(field),
    );
  }
}

final passwordControllerProvider =
    NotifierProvider.autoDispose<PasswordController, ProfileFormState>(
      PasswordController.new,
    );
