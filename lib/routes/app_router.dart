import 'package:flutter/material.dart';
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

GoRouter createAppRouter({String initialLocation = '/login'}) {
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'root'),
    initialLocation: initialLocation,
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri.path}'),
      ),
    ),
    routes: <RouteBase>[
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) {
          return LoginScreen(
            onLoginSuccess: () {
              GoRouter.of(context).go('/');
            },
          );
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
}

final GoRouter appRouter = createAppRouter();
