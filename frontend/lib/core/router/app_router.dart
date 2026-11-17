import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/router/app_shell.dart';
import 'package:servora/core/router/auth_status.dart';
import 'package:servora/core/router/placeholder_pages.dart';
import 'package:servora/core/router/routes.dart';
import 'package:servora/features/auth/presentation/login_screen.dart';
import 'package:servora/features/auth/presentation/register_screen.dart';
import 'package:servora/features/services/presentation/home_screen.dart';

/// Decides where a user may go. Pure function so it can be unit tested.
///
/// Returns null to allow [location], or the path to redirect to.
String? redirectFor(AuthStatus status, String location) {
  switch (status) {
    case AuthStatus.unknown:
      // Session restore in progress: hold everyone on the splash screen.
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case AuthStatus.unauthenticated:
      return AppRoutes.publicRoutes.contains(location) &&
              location != AppRoutes.splash
          ? null
          : AppRoutes.login;
    case AuthStatus.authenticated:
      return AppRoutes.publicRoutes.contains(location) ? AppRoutes.home : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  // go_router re-runs its redirect whenever this notifies.
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthStatus>(authStatusProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) =>
        redirectFor(ref.read(authStatusProvider), state.uri.path),
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashPage()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.bookings,
                builder: (_, _) => const BookingsPlaceholderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.assistant,
                builder: (_, _) => const AssistantPlaceholderPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (_, _) => const ProfilePlaceholderPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
