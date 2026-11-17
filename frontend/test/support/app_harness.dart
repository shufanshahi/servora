import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/app.dart';
import 'package:servora/core/router/auth_status.dart';

class _FixedAuthStatus extends AuthStatusNotifier {
  _FixedAuthStatus(this.initial);

  final AuthStatus initial;

  @override
  AuthStatus build() => initial;
}

/// The whole app with a chosen starting auth state.
Widget servoraApp({AuthStatus status = AuthStatus.unauthenticated}) {
  return ProviderScope(
    overrides: [
      authStatusProvider.overrideWith(() => _FixedAuthStatus(status)),
    ],
    child: const ServoraApp(),
  );
}

/// Sets a logical screen size (dp) for the test and restores it afterwards.
void useScreen(
  WidgetTester tester, {
  required double width,
  required double height,
  double textScale = 1.0,
}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = Size(width, height);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
