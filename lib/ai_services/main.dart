// lib/main.dart

import 'package:flutter/material.dart';

import 'features/ai_assistant/screens/ai_assistant_screen.dart';

void main() {
  runApp(const StudentCompanionApp());
}

class StudentCompanionApp extends StatelessWidget {
  const StudentCompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF2952CC);

    return MaterialApp(
      title: 'Student Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FC),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Color(0xFF172033),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F8FC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      // Go directly to the AI chat screen.
      home: const AIAssistantScreen(),
    );
  }
}
