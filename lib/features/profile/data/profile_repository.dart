import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/domain/app_user.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/network/providers.dart';

/// The signed-in user's own account. Throws [AppFailure] for every kind of failure.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  /// The current user from the server. A 401 means the saved session is no longer valid.
  Future<AppUser> me() async {
    final response = await _api.get('/users/me');
    return _user(response.data);
  }

  /// Saves name and phone. A null or blank [phone] removes the number.
  Future<AppUser> update({required String name, String? phone}) async {
    final trimmed = phone?.trim();
    final response = await _api.patch(
      '/users/me',
      body: {
        'name': name.trim(),
        'phone': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      },
    );
    return _user(response.data);
  }

  /// A wrong [currentPassword] is an [UnauthenticatedFailure] with code
  /// `INVALID_CREDENTIALS` (it does not end the session).
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/users/me/password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  static AppUser _user(Object? data) {
    try {
      return AppUser.fromJson(data! as Map<String, dynamic>);
    } on Object {
      throw const UnknownFailure();
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(apiClientProvider)),
);
