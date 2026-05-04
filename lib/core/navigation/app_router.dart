import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'package:student_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:student_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:student_companion/features/home/presentation/screens/home_screen.dart';
import 'package:student_companion/shared/screens/loading_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final router = GoRouter(
    refreshListenable: authProvider,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authProvider.status;
      final isLoggingIn = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      // While initializing, return null to let the router handle the current state
      // or redirect to a loading route if we want more control.
      if (status == AuthStatus.initial) return '/loading';

      final bool loggedIn = status == AuthStatus.authenticated;

      if (!loggedIn) {
        // If not logged in and not on auth pages, go to login
        return isLoggingIn ? null : '/login';
      }

      // If logged in and on auth pages, go to home
      if (isLoggingIn || state.matchedLocation == '/loading') {
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
    ],
  );
}

