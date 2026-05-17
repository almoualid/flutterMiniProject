// lib/screens/notifications_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// TÂCHE 3 : Écran des notifications / rappels à venir
//
// Affiche la liste des devoirs avec leur statut de rappel :
//   • 🔴 Expiré    (deadline passée, non fait)
//   • 🟡 Urgent    (moins de 24h)
//   • 🟢 Rappel    (planifié 24h avant)
//   • ✅ Terminé   (devoir fait)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_academic_manager/models/homework.dart';
import 'package:student_academic_manager/repositories/homework_repository.dart';
import 'package:student_academic_manager/utils/notification_helper.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final HomeworkRepository repo = HomeworkRepository();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rappels & Notifications'),
        centerTitle: true,
        actions: [
          // Bouton test notification
          IconButton(
            icon: const Icon(Icons.notifications_active),
            tooltip: 'Tester les notifications',
            onPressed: () async {
              await NotificationHelper.showTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Notification de test envoyée !'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Homework>>(
        stream: repo.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Erreur : ${snapshot.error}'),
            );
          }

          final allHomeworks = snapshot.data ?? [];

          // Filtrer les devoirs non terminés, trier par date limite
          final pendingHomeworks = allHomeworks
              .where((hw) => !hw.isDone)
              .toList()
            ..sort((a, b) => a.deadline.compareTo(b.deadline));

          final doneHomeworks = allHomeworks
              .where((hw) => hw.isDone)
              .toList();

          if (allHomeworks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun devoir enregistré',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Ajoutez des devoirs pour recevoir des rappels',
                    style: TextStyle(color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── En attente ────────────────────────────────────────────────
              if (pendingHomeworks.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Rappels programmés (${pendingHomeworks.length})',
                  icon: Icons.alarm,
                  color: Colors.blue,
                ),
                const SizedBox(height: 8),
                ...pendingHomeworks.map(
                  (hw) => _HomeworkNotificationCard(
                    homework: hw,
                    onReschedule: () async {
                      await NotificationHelper.scheduleOrShowReminder(hw);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rappel reprogrammé pour "${hw.title}"'),
                            backgroundColor: Colors.blue,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],

              // ── Terminés ──────────────────────────────────────────────────
              if (doneHomeworks.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Devoirs terminés (${doneHomeworks.length})',
                  icon: Icons.check_circle,
                  color: Colors.green,
                ),
                const SizedBox(height: 8),
                ...doneHomeworks.map(
                  (hw) => _HomeworkNotificationCard(homework: hw),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget : En-tête de section
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget : Carte d'un devoir avec son statut de notification
// ─────────────────────────────────────────────────────────────────────────────
class _HomeworkNotificationCard extends StatelessWidget {
  final Homework homework;
  final VoidCallback? onReschedule;

  const _HomeworkNotificationCard({
    required this.homework,
    this.onReschedule,
  });

  // Calculer le statut de notification
  _NotifStatus _getStatus() {
    if (homework.isDone) return _NotifStatus.done;

    final now = DateTime.now();
    final deadline = homework.deadline;
    final reminderTime = deadline.subtract(const Duration(hours: 24));

    if (deadline.isBefore(now)) return _NotifStatus.overdue;
    if (reminderTime.isBefore(now)) return _NotifStatus.urgent;
    return _NotifStatus.scheduled;
  }

  @override
  Widget build(BuildContext context) {
    final status = _getStatus();
    final now = DateTime.now();
    final remaining = homework.deadline.difference(now);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: status.color.withOpacity(0.15),
          child: Icon(status.icon, color: status.color, size: 20),
        ),
        title: Text(
          homework.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: homework.isDone ? TextDecoration.lineThrough : null,
            color: homework.isDone ? Colors.grey : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date limite : ${DateFormat('dd/MM/yyyy').format(homework.deadline)}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              status.label(remaining),
              style: TextStyle(
                fontSize: 11,
                color: status.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: onReschedule != null
            ? IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: 'Reprogrammer le rappel',
                onPressed: onReschedule,
              )
            : null,
        isThreeLine: true,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum : statuts de notification
// ─────────────────────────────────────────────────────────────────────────────
enum _NotifStatus {
  done,
  overdue,
  urgent,
  scheduled;

  Color get color {
    switch (this) {
      case _NotifStatus.done:      return Colors.green;
      case _NotifStatus.overdue:   return Colors.red;
      case _NotifStatus.urgent:    return Colors.orange;
      case _NotifStatus.scheduled: return Colors.blue;
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifStatus.done:      return Icons.check_circle;
      case _NotifStatus.overdue:   return Icons.error;
      case _NotifStatus.urgent:    return Icons.warning;
      case _NotifStatus.scheduled: return Icons.alarm;
    }
  }

  String label(Duration remaining) {
    switch (this) {
      case _NotifStatus.done:
        return '✅ Terminé';
      case _NotifStatus.overdue:
        return '🔴 Expiré il y a ${remaining.abs().inHours}h';
      case _NotifStatus.urgent:
        final h = remaining.inHours;
        final m = remaining.inMinutes.remainder(60);
        return '🟡 Urgent — dans ${h}h${m.toString().padLeft(2, '0')}min';
      case _NotifStatus.scheduled:
        final days = remaining.inDays;
        if (days > 1) return '🔔 Rappel dans $days jours';
        return '🔔 Rappel dans moins de 2 jours';
    }
  }
}