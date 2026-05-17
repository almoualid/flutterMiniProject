// lib/services/notification_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// TÂCHE 3 : Service de Notifications
//
// Responsabilités :
//   1. Initialiser flutter_local_notifications + timezone
//   2. Demander les permissions Android/iOS
//   3. Configurer Firebase Cloud Messaging (foreground / background / terminated)
//   4. Afficher des notifications immédiates (showNotification)
//   5. Programmer des rappels 24h avant la date limite (scheduleHomeworkReminder)
//   6. Annuler les notifications (cancelNotification, cancelHomeworkNotification)
//
// Mode offline : flutter_local_notifications fonctionne SANS internet.
//   → Les rappels programmés se déclenchent même hors ligne.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─────────────────────────────────────────────────────────────────────────────
// Handler FCM exécuté dans un ISOLAT séparé (background / terminated)
// DOIT être une fonction top-level (pas de méthode de classe)
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase doit être initialisé dans cet isolat
  await Firebase.initializeApp();
  print('[FCM Background] Message reçu : ${message.messageId}');
  print('[FCM Background] Title : ${message.notification?.title}');
  print('[FCM Background] Body  : ${message.notification?.body}');

  // Afficher une notification locale dans le contexte background
  final FlutterLocalNotificationsPlugin plugin = FlutterLocalNotificationsPlugin();

  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  await plugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  if (message.notification != null) {
    await plugin.show(
      message.hashCode,
      message.notification!.title ?? 'Rappel',
      message.notification!.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          NotificationService.channelId,
          NotificationService.channelName,
          channelDescription: NotificationService.channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: message.data['payload'],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Classe principale NotificationService (Singleton)
// ─────────────────────────────────────────────────────────────────────────────
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // ── Constantes du canal de notification Android ───────────────────────────
  static const String channelId          = 'student_companion_reminders';
  static const String channelName        = 'Rappels Devoirs';
  static const String channelDescription = 'Rappels automatiques 24h avant la date limite';

  // ── Instances plugins ─────────────────────────────────────────────────────
  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ── État ──────────────────────────────────────────────────────────────────
  bool _initialized = false;

  // ══════════════════════════════════════════════════════════════════════════
  //  init() — à appeler AVANT runApp() dans main.dart
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> init() async {
    if (_initialized) return;

    print('[NotificationService] Initialisation...');

    // 1. Initialiser les fuseaux horaires (requis pour zonedSchedule)
    tz.initializeTimeZones();
    _setLocalTimezone();

    // 2. Initialiser flutter_local_notifications
    await _initLocalNotifications();

    // 3. Demander les permissions
    await requestPermission();

    // 4. Configurer FCM
    await setupFirebaseMessaging();

    _initialized = true;
    print('[NotificationService] Initialisé ✓');
  }

  // ── Détecter et définir le fuseau horaire local ───────────────────────────
  void _setLocalTimezone() {
    try {
      // Sur mobile, utilise le fuseau système. Sur desktop/web, fallback UTC.
      final locationName = DateTime.now().timeZoneName;
      final locations = tz.timeZoneDatabase.locations;
      if (locations.containsKey(locationName)) {
        tz.setLocalLocation(tz.getLocation(locationName));
      } else {
        // Fallback : Africa/Casablanca pour le Maroc, ou UTC
        tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
      }
    } catch (e) {
      print('[NotificationService] Fuseau horaire : fallback UTC ($e)');
      tz.setLocalLocation(tz.UTC);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  Initialisation flutter_local_notifications
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _initLocalNotifications() async {
    // ── Paramètres Android ────────────────────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // ── Paramètres iOS / macOS ────────────────────────────────────────────
    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false, // On gère les permissions séparément
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _localPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTapped,
    );

    // Créer le canal Android (Android 8+)
    await _createAndroidChannel();

    print('[NotificationService] flutter_local_notifications prêt ✓');
  }

  // ── Créer le canal de notification Android ────────────────────────────────
  Future<void> _createAndroidChannel() async {
    if (!Platform.isAndroid) return;

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    print('[NotificationService] Canal Android "$channelName" créé ✓');
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  requestPermission() — demander les permissions notification
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> requestPermission() async {
    // ── iOS / macOS ───────────────────────────────────────────────────────
    if (Platform.isIOS || Platform.isMacOS) {
      final bool? granted = await _localPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      print('[NotificationService] Permission iOS : $granted');
    }

    // ── Android 13+ (API 33+) ─────────────────────────────────────────────
    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _localPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final bool? granted =
          await androidPlugin?.requestNotificationsPermission();
      print('[NotificationService] Permission Android : $granted');

      // Permission SCHEDULE_EXACT_ALARM (Android 12+)
      final bool? exactAlarmGranted =
          await androidPlugin?.requestExactAlarmsPermission();
      print('[NotificationService] Exact Alarm Android : $exactAlarmGranted');
    }

    // ── FCM (demande aussi les permissions sur iOS) ───────────────────────
    final NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print(
      '[NotificationService] Statut FCM : ${settings.authorizationStatus}',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  setupFirebaseMessaging() — configurer les listeners FCM
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> setupFirebaseMessaging() async {
    // ── Handler global pour les messages BACKGROUND / TERMINATED ─────────
    // Enregistré ici, mais la fonction est top-level (définie au-dessus)
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── Messages reçus en FOREGROUND ──────────────────────────────────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('[FCM Foreground] Message reçu : ${message.messageId}');
      _handleForegroundMessage(message);
    });

    // ── Application ouverte depuis une notification (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('[FCM] App ouverte via notification : ${message.messageId}');
      _handleNotificationOpenedApp(message);
    });

    // ── Notification initiale (app était TERMINATED et ouverte via notif) ──
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      print('[FCM] App lancée via notification : ${initialMessage.messageId}');
      _handleNotificationOpenedApp(initialMessage);
    }

    // ── Token FCM (pour envoi de push depuis backend) ─────────────────────
    final String? token = await _fcm.getToken();
    print('[FCM] Token : $token');

    // Écouter les renouvellements de token
    _fcm.onTokenRefresh.listen((newToken) {
      print('[FCM] Nouveau token : $newToken');
      // TODO: envoyer le token vers Firestore si auth est implémentée
    });

    print('[NotificationService] FCM configuré ✓');
  }

  // ── Afficher une notification locale en foreground ────────────────────────
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.notification == null) return;

    await showNotification(
      id: message.hashCode,
      title: message.notification!.title ?? 'Nouveau message',
      body: message.notification!.body ?? '',
      payload: message.data['payload'],
    );
  }

  // ── Gérer l'ouverture de l'app via une notification ───────────────────────
  void _handleNotificationOpenedApp(RemoteMessage message) {
    // TODO (Tâche 3 avancée) : naviguer vers le devoir concerné
    // via le payload message.data['homeworkId']
    print('[NotificationService] Payload navigation : ${message.data}');
  }

  // ── Callback quand l'utilisateur tape sur une notification locale ─────────
  static void _onNotificationTapped(NotificationResponse response) {
    print('[NotificationService] Notification tapée | payload: ${response.payload}');
    // TODO : naviguer vers l'écran du devoir si payload contient l'ID
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    print('[NotificationService] Background notification tapée | payload: ${response.payload}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  showNotification() — afficher une notification IMMÉDIATE
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    print('[NotificationService] showNotification : "$title"');

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _localPlugin.show(id, title, body, details, payload: payload);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  scheduleHomeworkReminder() — programmer un rappel 24h avant la deadline
  //
  //  Logique :
  //    • deadline - 24h > maintenant  → programmer à deadline - 24h
  //    • deadline > maintenant mais < 24h  → afficher immédiatement
  //    • deadline passée  → ne pas programmer
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> scheduleHomeworkReminder({
    required String homeworkId,
    required String title,
    required DateTime deadline,
  }) async {
    final int notifId = _notificationIdFromHomeworkId(homeworkId);
    final DateTime now = DateTime.now();
    final DateTime reminderTime = deadline.subtract(const Duration(hours: 24));

    // Cas 1 : date limite déjà passée
    if (deadline.isBefore(now)) {
      print(
        '[NotificationService] Deadline passée pour "$title" → pas de rappel',
      );
      return;
    }

    // Cas 2 : moins de 24h restantes → notification immédiate
    if (reminderTime.isBefore(now)) {
      final Duration remaining = deadline.difference(now);
      final String remainingStr = _formatDuration(remaining);
      print(
        '[NotificationService] Moins de 24h pour "$title" → notification immédiate',
      );
      await showNotification(
        id: notifId,
        title: '⏰ Devoir bientôt dû : $title',
        body: 'Date limite dans $remainingStr !',
        payload: homeworkId,
      );
      return;
    }

    // Cas 3 : programmer le rappel à deadline - 24h
    final tz.TZDateTime scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    print(
      '[NotificationService] Rappel programmé pour "$title" le ${reminderTime.toString()}',
    );

    const NotificationDetails details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _localPlugin.zonedSchedule(
        notifId,
        '📚 Rappel : $title',
        'Date limite demain — pensez à remettre votre devoir !',
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: homeworkId,
      );
      print(
        '[NotificationService] Rappel programmé ✓ (id=$notifId)',
      );
    } catch (e) {
      print(
        '[NotificationService] Erreur lors de la programmation du rappel : $e',
      );
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  cancelNotification() — annuler une notification par son ID
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> cancelNotification(int notificationId) async {
    await _localPlugin.cancel(notificationId);
    print('[NotificationService] Notification $notificationId annulée ✓');
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  cancelHomeworkNotification() — annuler le rappel d'un devoir par son ID
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> cancelHomeworkNotification(String homeworkId) async {
    final int notifId = _notificationIdFromHomeworkId(homeworkId);
    await cancelNotification(notifId);
    print(
      '[NotificationService] Rappel du devoir "$homeworkId" annulé ✓',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  cancelAllNotifications() — annuler TOUTES les notifications programmées
  // ══════════════════════════════════════════════════════════════════════════
  Future<void> cancelAllNotifications() async {
    await _localPlugin.cancelAll();
    print('[NotificationService] Toutes les notifications annulées ✓');
  }

  // ── Utilitaire : convertir l'ID string du devoir en int stable ───────────
  int _notificationIdFromHomeworkId(String homeworkId) {
    // hashCode peut être négatif → on le rend positif et on le tronque
    return homeworkId.hashCode.abs() % 2147483647;
  }

  // ── Utilitaire : formater une durée en texte lisible ──────────────────────
  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours}h${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}min';
    }
    return '${duration.inMinutes}min';
  }
}