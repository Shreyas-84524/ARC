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
import 'package:arc/features/user_management/views/splash_screen.dart';
import 'package:arc/features/admin/screens/admin_dashboard_screen.dart';
import 'package:arc/features/user_management/providers/user_context_provider.dart';
import 'package:arc/features/user_management/models/user_context.dart';

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
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final userContext = _ref.read(userContextProvider);
    final location = state.uri.path;
    final isLoggingIn = location == '/login';
    final isSplash = location == '/splash';
    final isAdminRoute = location == '/admin';

    debugPrint(
        '[RouterNotifier.redirect] path: $location, isInitializing: ${userContext.isInitializing}, isAuthenticated: ${userContext.isAuthenticated}, isAdmin: ${userContext.isAdmin}');

    // 1. While auth state is initializing from Firebase Auth persistent storage
    if (userContext.isInitializing) {
      return isSplash ? null : '/splash';
    }

    // 2. If user is NOT authenticated
    if (!userContext.isAuthenticated) {
      return isLoggingIn ? null : '/login';
    }

    // 3. If user IS authenticated as Administrator
    if (userContext.isAdmin) {
      return isAdminRoute ? null : '/admin';
    }

    // 4. If normal user attempts to access /admin
    if (isAdminRoute) {
      return '/';
    }

    // 5. If user IS authenticated normal user on splash or login screen
    if (isLoggingIn || isSplash) {
      return '/';
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
              return const TasksScreen();
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
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
  );
}

final GoRouter appRouter = createAppRouter();
