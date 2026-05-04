import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:student_companion/core/navigation/app_router.dart';
import 'package:student_companion/core/theme/app_theme.dart';
import 'package:student_companion/features/auth/data/services/auth_service.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  // Note: For a real project, you'd need the google-services.json / GoogleService-Info.plist
  // or use 'flutterfire configure' to generate firebase_options.dart
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final authService = AuthService();
  final authProvider = AuthProvider(authService: authService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        Provider.value(value: authService),
      ],
      child: const StudentCompanionApp(),
    ),
  );
}

class StudentCompanionApp extends StatefulWidget {
  const StudentCompanionApp({super.key});

  @override
  State<StudentCompanionApp> createState() => _StudentCompanionAppState();
}

class _StudentCompanionAppState extends State<StudentCompanionApp> {
  late final AppRouter _appRouter;

  @override
  void initState() {
    super.initState();
    // Initialize the router with the auth provider for redirection logic
    _appRouter = AppRouter(context.read<AuthProvider>());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Student Companion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _appRouter.router,
    );
  }
}
