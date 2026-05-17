// lib/utils/notification_helper.dart
// ─────────────────────────────────────────────────────────────────────────────
// TÂCHE 3 : Utilitaires de notifications
//
// Fonctions helpers appelées par HomeworkRepository lors de :
//   • add()    → scheduleOrShowReminder()
//   • update() → rescheduleReminder()
//   • delete() → cancelReminder()
// ─────────────────────────────────────────────────────────────────────────────

import 'package:student_academic_manager/models/homework.dart';
import 'package:student_academic_manager/services/notification_service.dart';

class NotificationHelper {
  NotificationHelper._(); // classe utilitaire, pas d'instanciation

  static final NotificationService _notifService = NotificationService();

  // ══════════════════════════════════════════════════════════════════════════
  //  scheduleOrShowReminder()
  //  Appelé après l'ajout d'un devoir.
  //  Programme ou affiche immédiatement un rappel selon la deadline.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> scheduleOrShowReminder(Homework homework) async {
    // Ne pas notifier si le devoir est déjà terminé
    if (homework.isDone) {
      print(
        '[NotificationHelper] Devoir "${homework.title}" déjà fait → pas de rappel',
      );
      return;
    }

    await _notifService.scheduleHomeworkReminder(
      homeworkId: homework.id,
      title: homework.title,
      deadline: homework.deadline,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  rescheduleReminder()
  //  Appelé après la mise à jour d'un devoir.
  //  Annule l'ancienne notification et en programme une nouvelle.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> rescheduleReminder(Homework homework) async {
    // 1. Annuler l'ancienne notification
    await _notifService.cancelHomeworkNotification(homework.id);

    // 2. Ne pas reprogrammer si le devoir est terminé
    if (homework.isDone) {
      print(
        '[NotificationHelper] Devoir "${homework.title}" marqué fait → rappel annulé',
      );
      return;
    }

    // 3. Reprogrammer avec les nouvelles données
    await _notifService.scheduleHomeworkReminder(
      homeworkId: homework.id,
      title: homework.title,
      deadline: homework.deadline,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  cancelReminder()
  //  Appelé après la suppression d'un devoir.
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> cancelReminder(String homeworkId) async {
    await _notifService.cancelHomeworkNotification(homeworkId);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  showTestNotification()
  //  Pour tester rapidement le système de notifications (debug uniquement).
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> showTestNotification() async {
    await _notifService.showNotification(
      id: 9999,
      title: '✅ Notifications opérationnelles',
      body: 'Le système de rappels fonctionne correctement !',
      payload: 'test',
    );
    print('[NotificationHelper] Notification de test envoyée ✓');
  }
}