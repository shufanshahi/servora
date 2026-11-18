import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/config/app_config.dart';
import 'package:servora/core/network/api_client.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Where the API client reads the access token: the signed-in session, or nothing
/// when signed out. Read on every request, so a new login is picked up without
/// rebuilding the client.
final tokenProviderProvider = Provider<TokenProvider>((ref) {
  return () async {
    final session = ref.read(sessionProvider);
    return session is SessionAuthenticated ? session.accessToken : null;
  };
});

/// Called when a token is rejected with 401: ends the session so the router
/// returns to the login screen with an explanation.
final unauthorizedHandlerProvider = Provider<void Function()>((ref) {
  return () => unawaited(ref.read(sessionProvider.notifier).expire());
});

/// Replaces the network layer in tests. Null (the default) uses the real one.
final httpClientAdapterProvider = Provider<HttpClientAdapter?>((ref) => null);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    tokenProvider: ref.watch(tokenProviderProvider),
    onUnauthorized: ref.watch(unauthorizedHandlerProvider),
    httpClientAdapter: ref.watch(httpClientAdapterProvider),
  );
  ref.onDispose(client.close);
  return client;
});
