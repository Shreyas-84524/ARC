import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:arc/firebase_options.dart';
import 'package:arc/core/theme/app_theme.dart';
import 'package:arc/routes/app_router.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/core/notifications/notification_service.dart';
import 'package:arc/providers/global_providers.dart';

void main() async {
  runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError caught: ${details.exception}');
    };

    // Initialize Timezones
    tz.initializeTimeZones();

    // Initialize Firebase Cloud services
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('Firebase Core: successfully initialized.');
    } catch (e) {
      debugPrint('Firebase Core initialization warning: $e');
    }

    // Initialize Local Databases (Hive)
    try {
      await HiveService().init();
    } catch (e) {
      debugPrint('HiveService initialization warning: $e');
    }

    // Initialize Local Notifications
    try {
      final notificationService = NotificationService();
      await notificationService.init();
      await notificationService.requestPermissions();
    } catch (e) {
      debugPrint('NotificationService initialization warning: $e');
    }

    // Run the application
    runApp(
      const ProviderScope(
        child: ProjectArcApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('Uncaught async error in main: $error\n$stackTrace');
  });
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
