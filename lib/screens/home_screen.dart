// lib/screens/home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// TÂCHE 3 : Ajout d'un 3e onglet "Rappels" dans la BottomNavigationBar
// Le reste du code est identique à la tâche 2
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:student_academic_manager/services/sync_service.dart';
import 'package:student_academic_manager/screens/course_list_screen.dart';
import 'package:student_academic_manager/screens/homework_list_screen.dart';
import 'package:student_academic_manager/screens/notifications_screen.dart'; // TÂCHE 3

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isOnline = false;
  late StreamSubscription<bool> _connectivitySub;

  // TÂCHE 3 : ajout de l'écran Notifications
  final List<Widget> _screens = const [
    CourseListScreen(),
    HomeworkListScreen(),
    NotificationsScreen(), // TÂCHE 3
  ];

  @override
  void initState() {
    super.initState();
    _isOnline = SyncService().isOnline;

    _connectivitySub = SyncService().onlineStatus.listen((online) {
      if (mounted) {
        setState(() => _isOnline = online);

        if (online) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.sync, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Connexion rétablie — synchronisation en cours...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Bandeau mode offline (inchangé)
            if (!_isOnline)
              Material(
                color: Colors.orange.shade700,
                child: const SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mode hors ligne — les données sont sauvegardées localement',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            Expanded(
              child: HeroMode(
                enabled: false,
                child: IndexedStack(index: _selectedIndex, children: _screens),
              ),
            ),
          ],
        ),
      ),

      // TÂCHE 3 : 3e onglet "Rappels"
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Cours',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Devoirs',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Rappels',
          ),
        ],
      ),
    );
  }
}