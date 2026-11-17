// Calls GET /health on the Servora API using the app's own HTTP client.
//
//   dart run tool/check_api.dart [base-url]
//
// Exits 0 when the API answers, 1 otherwise. Handy for checking that an emulator,
// phone or hosted address is reachable before running the app.
import 'dart:io';

import 'package:servora/core/config/app_config.dart';
import 'package:servora/core/error/app_failure.dart';
import 'package:servora/core/network/api_client.dart';

Future<void> main(List<String> args) async {
  final config = args.isEmpty
      ? AppConfig.fromEnvironment()
      : AppConfig.parse(args.first);

  stdout.writeln('Checking ${config.apiBaseUrl}/health ...');
  final client = ApiClient(
    baseUrl: config.apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  );

  try {
    final response = await client.get('/health', authenticated: false);
    stdout.writeln('OK: ${response.data}');
  } on AppFailure catch (failure) {
    stderr.writeln('FAILED: ${failure.userMessage} (${failure.runtimeType})');
    exitCode = 1;
  } finally {
    client.close();
  }
}
