import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/network/api_response.dart';
import 'package:servora/core/network/providers.dart';
import 'package:servora/features/auth/domain/auth_result.dart';

/// Talks to the auth endpoints. Throws [AppFailure] for every kind of failure.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/register',
      body: {'name': name, 'email': email, 'password': password},
      // No token exists yet, and a failure here must never clear a session.
      authenticated: false,
    );
    return _parse(response);
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      authenticated: false,
    );
    return _parse(response);
  }

  AuthResult _parse(ApiResponse response) {
    try {
      return AuthResult.fromJson(response.data as Map<String, dynamic>);
    } on Object {
      // The server answered 2xx but not with the shape we expect.
      throw const UnknownFailure();
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
