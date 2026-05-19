import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:student_companion/core/navigation/app_router.dart';
import 'package:student_companion/core/theme/app_theme.dart';
import 'package:student_companion/features/auth/data/services/auth_service.dart';
import 'package:student_companion/features/auth/presentation/providers/auth_provider.dart';
import 'package:student_companion/features/notifications/data/services/notification_service.dart';
import 'package:student_companion/shared/data/services/local_service.dart';
import 'package:student_companion/shared/data/services/sync_service.dart';
import 'package:student_companion/features/ai_assistant/data/models/chat_message.dart';
import 'package:student_companion/features/ai_assistant/data/models/chat_session.dart';
import 'firebase_options.dart';
import 'shared/utils/firebase_diagnostics.dart';

/// Handler FCM background — DOIT être une fonction top-level
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('[FCM Background] Message reçu : ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Initialiser Firebase ────────────────────────────────────────────────
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Diagnostic Firebase
  await FirebaseDiagnostics.checkConnection();

  // ── 2. Enregistrer le handler FCM background ──────────────────────────────
  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    print('Error setting up FCM background handler: $e');
  }

  // ── 3. Initialiser Hive (stockage local offline-first) ────────────────────
  await Hive.initFlutter();

  // Adapters AI
  if (!Hive.isAdapterRegistered(20)) Hive.registerAdapter(MessageRoleAdapter());
  if (!Hive.isAdapterRegistered(21)) Hive.registerAdapter(ChatMessageAdapter());
  if (!Hive.isAdapterRegistered(22)) Hive.registerAdapter(ChatSessionAdapter());

  // Boxes courses & devoirs
  await Hive.openBox<String>(LocalService.coursesBoxName);
  await Hive.openBox<String>(LocalService.homeworksBoxName);
  await Hive.openBox<String>(LocalService.metaBoxName);

  // Box sessions AI
  if (!Hive.isBoxOpen('ai_chat_sessions')) {
    await Hive.openBox<ChatSession>('ai_chat_sessions');
  }

  // ── 4. Démarrer la synchronisation offline-first ───────────────────────────
  await SyncService().init();

  // ── 5. Initialiser les notifications ──────────────────────────────────────
  await NotificationService().init();

  // ── 6. Auth setup ─────────────────────────────────────────────────────────
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
