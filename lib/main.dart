// lib/main.dart
// ─────────────────────────────────────────────────────────────────────────────
// POINT D'ENTRÉE DE L'APPLICATION
//
// Modifications TÂCHE 3 :
//   1. Import + initialisation de NotificationService AVANT runApp()
//   2. Enregistrement du handler FCM background (top-level)
//   3. Le reste est identique à la tâche 2
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:student_academic_manager/services/local_service.dart';
import 'package:student_academic_manager/services/sync_service.dart';
import 'package:student_academic_manager/services/notification_service.dart'; // TÂCHE 3
import 'package:student_academic_manager/screens/home_screen.dart';
import 'package:student_academic_manager/screens/index.dart';
import 'package:student_academic_manager/models/index.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── 1. Initialiser Firebase ────────────────────────────────────────────────
  await Firebase.initializeApp();

  // ── 2. Enregistrer le handler FCM BACKGROUND (TÂCHE 3) ───────────────────
  // IMPORTANT : doit être appelé AVANT tout autre code Firebase
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ── 3. Initialiser Hive (stockage local) ──────────────────────────────────
  await Hive.initFlutter();
  await Hive.openBox<String>(LocalService.coursesBoxName);
  await Hive.openBox<String>(LocalService.homeworksBoxName);
  await Hive.openBox<String>(LocalService.metaBoxName);
  print('[main] Boxes Hive ouvertes ✓');

  // ── 4. Démarrer le service de synchronisation ──────────────────────────────
  await SyncService().init();
  print('[main] SyncService démarré ✓');

  // ── 5. Initialiser le service de notifications (TÂCHE 3) ─────────────────
  await NotificationService().init();
  print('[main] NotificationService démarré ✓');

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Student Academic Manager',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HomeScreen(),
      routes: {
        '/courses': (context) => const CourseListScreen(),
        '/courses/add': (context) => const CourseFormScreen(),
        '/homeworks': (context) => const HomeworkListScreen(),
        '/homeworks/add': (context) => const HomeworkFormScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/courses/edit') {
          final course = settings.arguments as Course;
          return MaterialPageRoute(
            builder: (context) => CourseFormScreen(course: course),
            settings: settings,
          );
        } else if (settings.name == '/homeworks/edit') {
          final homework = settings.arguments as Homework;
          return MaterialPageRoute(
            builder: (context) => HomeworkFormScreen(homework: homework),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}