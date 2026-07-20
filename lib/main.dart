import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:arc/firebase_options.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/routes/app_router.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/providers/global_providers.dart';

void main() async {
  // Ensure widget bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Cloud services
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase Core: successfully initialized.');
  } catch (e) {
    debugPrint('Firebase Core initialization failed: $e');
  }

  // Initialize Local Databases (Hive)
  await HiveService().init();

  // Initialize Local Notifications
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  // Run the application
  runApp(
    const ProviderScope(
      child: ProjectArcApp(),
    ),
  );
}

class ProjectArcApp extends ConsumerWidget {
  const ProjectArcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read the active theme state from Riverpod
    final activeThemeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Project Arc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: activeThemeMode,
      routerConfig: appRouter,
    );
  }
}
