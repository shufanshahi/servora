import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:servora/core/config/app_config.dart';
import 'package:servora/core/network/api_client.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

/// Where the API client reads the access token. Signed out until the auth feature
/// overrides this with the real session.
final tokenProviderProvider = Provider<TokenProvider>(
  (ref) =>
      () async => null,
);

/// Called when a token is rejected with 401. The auth feature overrides this to
/// clear the session and return to the login screen.
final unauthorizedHandlerProvider = Provider<void Function()>((ref) => () {});

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(
    baseUrl: ref.watch(appConfigProvider).apiBaseUrl,
    tokenProvider: ref.watch(tokenProviderProvider),
    onUnauthorized: ref.watch(unauthorizedHandlerProvider),
  );
  ref.onDispose(client.close);
  return client;
});
