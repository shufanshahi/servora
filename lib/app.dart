import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:servora/core/router/app_router.dart';
import 'package:servora/core/theme/app_theme.dart';

/// Root widget of the Servora app.
class ServoraApp extends ConsumerWidget {
  const ServoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Servora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
