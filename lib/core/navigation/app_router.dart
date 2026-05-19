import 'package:go_router/go_router.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'package:student_companion/features/auth/presentation/screens/login_screen.dart';
import 'package:student_companion/features/auth/presentation/screens/register_screen.dart';
import 'package:student_companion/features/home/presentation/screens/home_screen.dart';
import 'package:student_companion/features/courses/presentation/screens/course_form_screen.dart';
import 'package:student_companion/features/courses/data/models/course.dart';
import 'package:student_companion/features/homework/presentation/screens/homework_form_screen.dart';
import 'package:student_companion/features/homework/data/models/homework.dart';
import 'package:student_companion/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:student_companion/shared/screens/loading_screen.dart';

class AppRouter {
  final AuthProvider authProvider;

  AppRouter(this.authProvider);

  late final router = GoRouter(
    refreshListenable: authProvider,
    initialLocation: '/',
    redirect: (context, state) {
      final status = authProvider.status;
      final isAuthPage = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (status == AuthStatus.initial) return '/loading';

      final bool loggedIn = status == AuthStatus.authenticated;

      if (!loggedIn) {
        return isAuthPage ? null : '/login';
      }

      if (isAuthPage || state.matchedLocation == '/loading') {
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
      GoRoute(
        path: '/courses/add',
        builder: (context, state) => const CourseFormScreen(),
      ),
      GoRoute(
        path: '/courses/edit',
        builder: (context, state) {
          final course = state.extra as Course;
          return CourseFormScreen(course: course);
        },
      ),
      GoRoute(
        path: '/homeworks/add',
        builder: (context, state) => const HomeworkFormScreen(),
      ),
      GoRoute(
        path: '/homeworks/edit',
        builder: (context, state) {
          final homework = state.extra as Homework;
          return HomeworkFormScreen(homework: homework);
        },
      ),
      GoRoute(
        path: '/ai-assistant',
        builder: (context, state) => const AIAssistantScreen(),
      ),
    ],
  );
}
