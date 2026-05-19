import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:student_companion/features/homework/data/models/homework.dart';
import 'package:student_companion/features/homework/data/repositories/homework_repository.dart';
import 'package:student_companion/shared/utils/notification_helper.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final HomeworkRepository repo = HomeworkRepository();

    return Scaffold(
      body: StreamBuilder<List<Homework>>(
        stream: repo.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 60),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.redAccent)),
                ],
              ),
            );
          }

          final allHomeworks = snapshot.data ?? [];

          final pendingHomeworks = allHomeworks
              .where((hw) => !hw.isDone)
              .toList()
            ..sort((a, b) => a.deadline.compareTo(b.deadline));

          final doneHomeworks = allHomeworks
              .where((hw) => hw.isDone)
              .toList()
            ..sort((a, b) => b.deadline.compareTo(a.deadline));

          if (allHomeworks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text('Aucun rappel', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Ajoutez des devoirs pour recevoir des rappels', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (pendingHomeworks.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Rappels programmés (${pendingHomeworks.length})',
                  icon: Icons.alarm_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                ...pendingHomeworks.map(
                  (hw) => _HomeworkNotificationCard(
                    homework: hw,
                    onReschedule: () async {
                      await NotificationHelper.scheduleOrShowReminder(hw);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Rappel reprogrammé pour "${hw.title}"'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],

              if (doneHomeworks.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Devoirs terminés (${doneHomeworks.length})',
                  icon: Icons.check_circle_outline_rounded,
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                ...doneHomeworks.map(
                  (hw) => _HomeworkNotificationCard(homework: hw),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await NotificationHelper.showTestNotification();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Notification de test envoyée !'),
                backgroundColor: Colors.green.shade700,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        icon: const Icon(Icons.notifications_active_rounded),
        label: const Text('Tester'),
      ),
    );
  }
}

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
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

enum _NotifStatus {
  done,
  overdue,
  urgent,
  scheduled;

  Color get color {
    switch (this) {
      case _NotifStatus.done:      return Colors.green;
      case _NotifStatus.overdue:   return Colors.redAccent;
      case _NotifStatus.urgent:    return Colors.orangeAccent;
      case _NotifStatus.scheduled: return Colors.blueAccent;
    }
  }

  IconData get icon {
    switch (this) {
      case _NotifStatus.done:      return Icons.check_circle_rounded;
      case _NotifStatus.overdue:   return Icons.error_rounded;
      case _NotifStatus.urgent:    return Icons.warning_rounded;
      case _NotifStatus.scheduled: return Icons.alarm_rounded;
    }
  }

  String label(Duration remaining) {
    switch (this) {
      case _NotifStatus.done:
        return 'Terminé';
      case _NotifStatus.overdue:
        return 'Expiré il y a ${remaining.abs().inHours}h';
      case _NotifStatus.urgent:
        final h = remaining.inHours;
        final m = remaining.inMinutes.remainder(60);
        return 'Urgent — dans ${h}h${m.toString().padLeft(2, '0')}min';
      case _NotifStatus.scheduled:
        final days = remaining.inDays;
        if (days > 1) return 'Rappel dans $days jours';
        return 'Rappel dans moins de 2 jours';
    }
  }
}

class _HomeworkNotificationCard extends StatelessWidget {
  final Homework homework;
  final VoidCallback? onReschedule;

  const _HomeworkNotificationCard({
    required this.homework,
    this.onReschedule,
  });

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
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.2),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      color: homework.isDone ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3) : null,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: status.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(status.icon, color: status.color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homework.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      decoration: homework.isDone ? TextDecoration.lineThrough : null,
                      color: homework.isDone ? Theme.of(context).colorScheme.onSurfaceVariant : null,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(homework.deadline),
                        style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.label(remaining),
                    style: TextStyle(
                      fontSize: 12,
                      color: status.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (onReschedule != null)
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Reprogrammer',
                onPressed: onReschedule,
              ),
          ],
        ),
      ),
    );
  }
}
