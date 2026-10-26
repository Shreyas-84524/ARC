import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:arc/features/dashboard/screens/shell_screen.dart';
import 'package:arc/features/dashboard/screens/dashboard_screen.dart';
import 'package:arc/features/task_manager/screens/tasks_screen.dart';
import 'package:arc/features/habit_tracker/screens/habits_screen.dart';
import 'package:arc/features/money_tracker/screens/money_screen.dart';
import 'package:arc/features/settings/screens/settings_screen.dart';
import 'package:arc/features/search/screens/global_search_screen.dart';
import 'package:arc/features/notifications/screens/notification_center_screen.dart';
import 'package:arc/features/user_management/views/login_screen.dart';
import 'package:arc/features/user_management/views/signup_screen.dart';
import 'package:arc/features/user_management/views/forgot_password_screen.dart';
import 'package:arc/features/user_management/views/splash_screen.dart';
import 'package:arc/features/admin/screens/admin_dashboard_screen.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/models/user_context.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_setup_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_unlock_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_dashboard_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_note_editor_screen.dart';
import 'package:arc/features/secret_notes/screens/secret_notes_settings_screen.dart';
import 'package:arc/features/secret_notes/providers/secret_notes_provider.dart';
import 'package:arc/features/feedback/models/feedback_model.dart';
import 'package:arc/features/feedback/screens/bug_report_screen.dart';
import 'package:arc/features/feedback/screens/feature_request_screen.dart';
import 'package:arc/features/feedback/screens/general_feedback_screen.dart';
import 'package:arc/features/feedback/screens/rate_arc_screen.dart';
import 'package:arc/features/feedback/screens/my_feedback_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<UserContext>(
      userContextProvider,
      (previous, next) {
        if (previous != next) {
          notifyListeners();
        }
      },
    );
    _ref.listen<bool>(
      secretNotesSessionProvider,
      (previous, next) {
        if (previous != next) {
          notifyListeners();
        }
      },
    );
    _ref.listen<AsyncValue<bool>>(
      secretNotesConfiguredProvider,
      (previous, next) {
        if (previous != next) {
          notifyListeners();
        }
      },
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final userContext = _ref.read(userContextProvider);
    final location = state.uri.path;
    final isLoggingIn = location == '/login';
    final isSignUp = location == '/signup';
    final isForgotPassword = location == '/forgot-password';
    final isSplash = location == '/splash';
    final isAdminRoute = location == '/admin';
    final isPublicAuthRoute =
        isLoggingIn || isSignUp || isForgotPassword;
    final isSecretNotesRoute = location.startsWith('/secret-notes');
    final isSecretNotesSetup = location == '/secret-notes/setup';
    final isSecretNotesUnlock = location == '/secret-notes/unlock';

    debugPrint(
        '[RouterNotifier.redirect] path: $location, isInitializing: ${userContext.isInitializing}, isAuthenticated: ${userContext.isAuthenticated}, isAdmin: ${userContext.isAdmin}');

    // 1. While auth state is initializing from Firebase Auth persistent storage
    if (userContext.isInitializing) {
      return isSplash ? null : '/splash';
    }

    // 2. If user is NOT authenticated
    if (!userContext.isAuthenticated) {
      _ref.read(secretNotesSessionProvider.notifier).lock();
      return isPublicAuthRoute ? null : '/login';
    }

    // 3. If user IS authenticated as Administrator
    if (userContext.isAdmin) {
      return isAdminRoute ? null : '/admin';
    }

    // 4. If normal user attempts to access /admin
    if (isAdminRoute) {
      return '/';
    }

    // 5. If user IS authenticated normal user on splash or public auth screen
    if (isPublicAuthRoute || isSplash) {
      return '/';
    }

    // 6. Secret Notes navigation and security gate
    if (isSecretNotesRoute) {
      // Entering Secret Notes: enable secure window protection on supported platforms (Android)
      _ref.read(secretNotesWindowPrivacyServiceProvider).enableSecureScreen();

      final securityService = _ref.read(secretNotesSecurityServiceProvider);
      final isConfigured = securityService.isConfiguredSync();
      final isUnlocked = _ref.read(secretNotesSessionProvider);

      if (!isConfigured) {
        return isSecretNotesSetup ? null : '/secret-notes/setup';
      }

      if (!isUnlocked) {
        return isSecretNotesUnlock ? null : '/secret-notes/unlock';
      }

      if (isSecretNotesSetup || isSecretNotesUnlock) {
        return '/secret-notes';
      }
    } else {
      // Exiting Secret Notes: disable secure screen protection and automatically invalidate unlocked session
      _ref.read(secretNotesWindowPrivacyServiceProvider).disableSecureScreen();
      final wasUnlocked = _ref.read(secretNotesSessionProvider);
      if (wasUnlocked) {
        _ref.read(secretNotesSessionProvider.notifier).lock();
        debugPrint('[RouterNotifier] User navigated out of Secret Notes. Session automatically locked.');
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/splash',
        builder: (BuildContext context, GoRouterState state) {
          return const SplashScreen();
        },
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return LoginScreen(
            onLoginSuccess: () {
              final userContext = ref.read(userContextProvider);
              if (userContext.isAdmin) {
                GoRouter.of(context).go('/admin');
              } else {
                GoRouter.of(context).go('/');
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) {
          return SignUpScreen(
            onSignUpSuccess: () {
              final userContext = ref.read(userContextProvider);
              if (userContext.isAdmin) {
                GoRouter.of(context).go('/admin');
              } else {
                GoRouter.of(context).go('/');
              }
            },
          );
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (BuildContext context, GoRouterState state) {
          return const ForgotPasswordScreen();
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (BuildContext context, GoRouterState state) {
          return const AdminDashboardScreen();
        },
      ),
      ShellRoute(
        builder: (BuildContext context, GoRouterState state, Widget child) {
          return ShellScreen(location: state.uri.path, child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) {
              return const DashboardScreen();
            },
          ),
          GoRoute(
            path: '/tasks',
            builder: (BuildContext context, GoRouterState state) {
              final taskId = state.uri.queryParameters['taskId'];
              return TasksScreen(initialTaskId: taskId);
            },
          ),
          GoRoute(
            path: '/habits',
            builder: (BuildContext context, GoRouterState state) {
              return const HabitsScreen();
            },
          ),
          GoRoute(
            path: '/money',
            builder: (BuildContext context, GoRouterState state) {
              return const MoneyScreen();
            },
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SettingsScreen();
        },
      ),
      GoRoute(
        path: '/feedback',
        builder: (BuildContext context, GoRouterState state) {
          final category = state.uri.queryParameters['category'];
          if (category == FeedbackCategory.bugReport) {
            return const BugReportScreen();
          } else if (category == FeedbackCategory.featureRequest) {
            return const FeatureRequestScreen();
          } else if (category == FeedbackCategory.generalFeedback) {
            return const GeneralFeedbackScreen();
          } else if (category == FeedbackCategory.appRating || category == 'rate_arc') {
            return const RateArcScreen();
          }
          return const GeneralFeedbackScreen();
        },
        routes: [
          GoRoute(
            path: 'bug',
            builder: (BuildContext context, GoRouterState state) => const BugReportScreen(),
          ),
          GoRoute(
            path: 'feature',
            builder: (BuildContext context, GoRouterState state) => const FeatureRequestScreen(),
          ),
          GoRoute(
            path: 'general',
            builder: (BuildContext context, GoRouterState state) => const GeneralFeedbackScreen(),
          ),
          GoRoute(
            path: 'rate',
            builder: (BuildContext context, GoRouterState state) => const RateArcScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/feedback/my-feedback',
        builder: (BuildContext context, GoRouterState state) {
          return const MyFeedbackScreen();
        },
      ),
      GoRoute(
        path: '/search',
        builder: (BuildContext context, GoRouterState state) {
          return const GlobalSearchScreen();
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (BuildContext context, GoRouterState state) {
          return const NotificationCenterScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes/setup',
        builder: (BuildContext context, GoRouterState state) {
          return const SecretNotesSetupScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes/unlock',
        builder: (BuildContext context, GoRouterState state) {
          return const SecretNotesUnlockScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes',
        builder: (BuildContext context, GoRouterState state) {
          return const SecretNotesDashboardScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes/settings',
        builder: (BuildContext context, GoRouterState state) {
          return const SecretNotesSettingsScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes/new',
        builder: (BuildContext context, GoRouterState state) {
          return const SecretNoteEditorScreen();
        },
      ),
      GoRoute(
        path: '/secret-notes/:id',
        builder: (BuildContext context, GoRouterState state) {
          final noteId = state.pathParameters['id'] ?? '';
          return SecretNoteEditorScreen(noteId: noteId);
        },
      ),
    ],
  );
});

GoRouter createAppRouter({String initialLocation = '/login'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(onLoginSuccess: () {}),
      ),
      GoRoute(
        path: '/signup',
        builder: (context, state) => SignUpScreen(onSignUpSuccess: () {}),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/secret-notes/setup',
        builder: (context, state) => const SecretNotesSetupScreen(),
      ),
      GoRoute(
        path: '/secret-notes/unlock',
        builder: (context, state) => const SecretNotesUnlockScreen(),
      ),
      GoRoute(
        path: '/secret-notes',
        builder: (context, state) => const SecretNotesDashboardScreen(),
      ),
      GoRoute(
        path: '/secret-notes/settings',
        builder: (context, state) => const SecretNotesSettingsScreen(),
      ),
      GoRoute(
        path: '/secret-notes/new',
        builder: (context, state) => const SecretNoteEditorScreen(),
      ),
      GoRoute(
        path: '/secret-notes/:id',
        builder: (context, state) {
          final noteId = state.pathParameters['id'] ?? '';
          return SecretNoteEditorScreen(noteId: noteId);
        },
      ),
    ],
  );
}

final GoRouter appRouter = createAppRouter();
