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
import 'package:arc/core/notifications/notification_reconciler.dart';
import 'package:arc/providers/global_providers.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';

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
      await notificationService.checkAppLaunchNotification();
    } catch (e) {
      debugPrint('NotificationService initialization warning: $e');
    }

    // Run the application
    runApp(
      const ProviderScope(
        child: SyncInitializer(
          child: ProjectArcApp(),
        ),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('Uncaught async error in main: $error\n$stackTrace');
  });
}

class SyncInitializer extends ConsumerStatefulWidget {
  final Widget child;
  const SyncInitializer({super.key, required this.child});

  @override
  ConsumerState<SyncInitializer> createState() => _SyncInitializerState();
}

class _SyncInitializerState extends ConsumerState<SyncInitializer> {
  @override
  void initState() {
    super.initState();
    _startSyncProcess();
  }

  Future<void> _startSyncProcess() async {
    final userContext = ref.read(userContextProvider);
    // Unauthenticated sessions must NOT perform Firestore background sync
    if (!userContext.isAuthenticated || userContext.userId == null) {
      return;
    }

    try {
      await HiveService().ensureUserBoxesOpened(userContext.userId);

      final syncService = ref.read(syncServiceProvider);
      final syncManager = ref.read(syncManagerProvider);

      void refreshAllNotifiers() {
        if (!mounted) return;
        ref.read(tasksProvider.notifier).refresh();
        ref.read(habitsProvider.notifier).refresh();
        ref.read(habitEntriesProvider.notifier).refresh();
        ref.read(moneyProvider.notifier).refresh();
        ref.read(monthlyBudgetProvider.notifier).refresh();
        ref.read(appSettingsProvider.notifier).refresh();
      }

      await syncManager.performFullSync(
        syncService: syncService,
        onRefreshState: refreshAllNotifiers,
      );
      syncService.startRealTimeSync(onRefreshState: refreshAllNotifiers);

      // Reconcile scheduled notifications for the authenticated user
      final settings = ref.read(appSettingsProvider);
      await NotificationReconciler().reconcile(
        userId: userContext.userId,
        tasks: ref.read(tasksProvider),
        habits: ref.read(habitsProvider),
        habitEntries: ref.read(habitEntriesProvider),
        remTime: settings.remTime,
        settings: settings,
      );
    } catch (e) {
      debugPrint('SyncInitializer background sync notice: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UserContext>(userContextProvider, (previous, next) {
      if (next.isAuthenticated && (previous == null || !previous.isAuthenticated)) {
        _startSyncProcess();
      }
    });

    return widget.child;
  }
}

class ProjectArcApp extends ConsumerStatefulWidget {
  const ProjectArcApp({super.key});

  @override
  ConsumerState<ProjectArcApp> createState() => _ProjectArcAppState();
}

class _ProjectArcAppState extends ConsumerState<ProjectArcApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Automatic lock when ARC leaves foreground (inactive, paused, hidden, detached)
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      final isUnlocked = ref.read(secretNotesSessionProvider);
      if (isUnlocked) {
        ref.read(secretNotesSessionProvider.notifier).lock();
        debugPrint('ProjectArcApp: app backgrounded (${state.name}). Secret Notes automatically locked.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Read the active theme state and reactive router from Riverpod
    final activeThemeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Project Arc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: activeThemeMode,
      routerConfig: router,
    );
  }
}
