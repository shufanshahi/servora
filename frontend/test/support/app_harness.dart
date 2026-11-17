import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show NavigationBar;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:servora/app.dart';
import 'package:servora/core/session/session_notifier.dart';
import 'package:servora/core/session/session_state.dart';
import 'package:servora/core/session/token_store.dart';

import 'package:servora/features/booking/data/appointments_repository.dart';
import 'package:servora/features/booking/presentation/booking_providers.dart';
import 'package:servora/features/services/data/services_repository.dart';
import 'package:servora/features/services/presentation/services_providers.dart';
import 'package:servora/features/services/presentation/widgets/service_image.dart';

import 'fake_appointments_repository.dart';
import 'fake_services_repository.dart';
import 'fake_token_store.dart';
import 'fixtures.dart';
import 'service_fixtures.dart';

/// A one-pixel PNG, so screens can show an image without any network or plugin.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Overrides that keep the Home tab off the network: the ten real services from a fake
/// repository, in-memory images and a short search debounce.
List<Override> serviceOverrides({
  ServicesRepository? repository,
  ServiceImageProviderFactory? imageFactory,
}) => [
  servicesRepositoryProvider.overrideWithValue(
    repository ?? FakeServicesRepository(realServices()),
  ),
  serviceImageProviderFactoryProvider.overrideWithValue(
    imageFactory ?? (url) => MemoryImage(_pixel),
  ),
  searchDebounceProvider.overrideWithValue(const Duration(milliseconds: 20)),
];

/// Overrides that keep the booking screens off the network, with the clock fixed at
/// Wednesday 1 May 2030, 08:00 UTC (the default) so "today" is the same on every run.
List<Override> bookingOverrides({
  AppointmentsRepository? repository,
  DateTime? now,
}) => [
  appointmentsRepositoryProvider.overrideWithValue(
    repository ?? FakeAppointmentsRepository(),
  ),
  nowProvider.overrideWithValue(() => now ?? DateTime(2030, 5, 1, 8)),
];

/// A session that is exactly [initial] and never restores from storage, so a test
/// can start in any state without waiting.
class _FixedSession extends SessionNotifier {
  _FixedSession(this.initial);

  final SessionState initial;

  @override
  SessionState build() => initial;
}

SessionState sessionFor(AuthStatus status) => switch (status) {
  AuthStatus.unknown => const SessionUnknown(),
  AuthStatus.unauthenticated => const SessionUnauthenticated(),
  AuthStatus.authenticated => SessionAuthenticated(
    user: testUser,
    accessToken: 'jwt-token',
    expiresAt: DateTime.utc(2099),
  ),
};

/// The whole app starting in a chosen auth state, with the session held in memory.
Widget servoraApp({
  AuthStatus status = AuthStatus.unauthenticated,
  SessionState? session,
  List<Override> overrides = const [],
  ServicesRepository? servicesRepository,
  ServiceImageProviderFactory? imageFactory,
  AppointmentsRepository? appointmentsRepository,
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      sessionProvider.overrideWith(
        () => _FixedSession(session ?? sessionFor(status)),
      ),
      ...serviceOverrides(
        repository: servicesRepository,
        imageFactory: imageFactory,
      ),
      ...bookingOverrides(repository: appointmentsRepository, now: now),
      ...overrides,
    ],
    child: const ServoraApp(),
  );
}

/// The whole app with the REAL session notifier on top of [store], for tests that
/// sign in and out. Starts in "unknown" and restores from [store] like a real launch.
Widget servoraAppWithRealSession(
  FakeTokenStore store, {
  List<Override> overrides = const [],
  ServicesRepository? servicesRepository,
  ServiceImageProviderFactory? imageFactory,
  AppointmentsRepository? appointmentsRepository,
  DateTime? now,
}) {
  return ProviderScope(
    overrides: [
      tokenStoreProvider.overrideWithValue(store),
      ...serviceOverrides(
        repository: servicesRepository,
        imageFactory: imageFactory,
      ),
      ...bookingOverrides(repository: appointmentsRepository, now: now),
      ...overrides,
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

/// A bottom-navigation tab, found by its label. Use this instead of `find.text` when
/// tapping tabs: a screen can contain the same word elsewhere (the Home tab and the
/// "Home" category chip, for instance).
Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));
