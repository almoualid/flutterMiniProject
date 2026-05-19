import 'package:student_companion/features/homework/data/models/homework.dart';
import 'package:student_companion/features/notifications/data/services/notification_service.dart';

class NotificationHelper {
  NotificationHelper._(); 

  static final NotificationService _notifService = NotificationService();

  static Future<void> scheduleOrShowReminder(Homework homework) async {
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

  static Future<void> rescheduleReminder(Homework homework) async {
    await _notifService.cancelHomeworkNotification(homework.id);

    if (homework.isDone) {
      print(
        '[NotificationHelper] Devoir "${homework.title}" marqué fait → rappel annulé',
      );
      return;
    }

    await _notifService.scheduleHomeworkReminder(
      homeworkId: homework.id,
      title: homework.title,
      deadline: homework.deadline,
    );
  }

  static Future<void> cancelReminder(String homeworkId) async {
    await _notifService.cancelHomeworkNotification(homeworkId);
  }

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
