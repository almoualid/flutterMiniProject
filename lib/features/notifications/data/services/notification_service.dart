import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart' show kIsWeb;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String channelId          = 'student_companion_reminders';
  static const String channelName        = 'Rappels Devoirs';
  static const String channelDescription = 'Rappels automatiques 24h avant la date limite';

  final FlutterLocalNotificationsPlugin _localPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    print('[NotificationService] Initialisation...');

    tz.initializeTimeZones();
    _setLocalTimezone();

    await _initLocalNotifications();
    await requestPermission();
    await setupFirebaseMessaging();

    _initialized = true;
    print('[NotificationService] Initialisé ✓');
  }

  void _setLocalTimezone() {
    try {
      final locationName = DateTime.now().timeZoneName;
      final locations = tz.timeZoneDatabase.locations;
      if (locations.containsKey(locationName)) {
        tz.setLocalLocation(tz.getLocation(locationName));
      } else {
        tz.setLocalLocation(tz.getLocation('Africa/Casablanca'));
      }
    } catch (e) {
      print('[NotificationService] Fuseau horaire : fallback UTC ($e)');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false, 
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

    await _createAndroidChannel();

    print('[NotificationService] flutter_local_notifications prêt ✓');
  }

  Future<void> _createAndroidChannel() async {
    if (kIsWeb || !Platform.isAndroid) return;

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

  Future<void> requestPermission() async {
    if (!kIsWeb) {
      if (Platform.isIOS || Platform.isMacOS) {
        final bool? granted = await _localPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>()
            ?.requestPermissions(alert: true, badge: true, sound: true);
        print('[NotificationService] Permission iOS : $granted');
      }

      if (Platform.isAndroid) {
        final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
            _localPlugin.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        final bool? granted =
            await androidPlugin?.requestNotificationsPermission();
        print('[NotificationService] Permission Android : $granted');

        final bool? exactAlarmGranted =
            await androidPlugin?.requestExactAlarmsPermission();
        print('[NotificationService] Exact Alarm Android : $exactAlarmGranted');
      }
    }

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

  Future<void> setupFirebaseMessaging() async {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('[FCM Foreground] Message reçu : ${message.messageId}');
        _handleForegroundMessage(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('[FCM] App ouverte via notification : ${message.messageId}');
        _handleNotificationOpenedApp(message);
      });

      final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        print('[FCM] App lancée via notification : ${initialMessage.messageId}');
        _handleNotificationOpenedApp(initialMessage);
      }

      final String? token = await _fcm.getToken();
      print('[FCM] Token : $token');

      _fcm.onTokenRefresh.listen((newToken) {
        print('[FCM] Nouveau token : $newToken');
      });

      print('[NotificationService] FCM configuré ✓');
    } catch (e) {
      print('[NotificationService] Erreur lors de la configuration FCM : $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (message.notification == null) return;

    await showNotification(
      id: message.hashCode,
      title: message.notification!.title ?? 'Nouveau message',
      body: message.notification!.body ?? '',
      payload: message.data['payload'],
    );
  }

  void _handleNotificationOpenedApp(RemoteMessage message) {
    print('[NotificationService] Payload navigation : ${message.data}');
  }

  static void _onNotificationTapped(NotificationResponse response) {
    print('[NotificationService] Notification tapée | payload: ${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTapped(NotificationResponse response) {
    print('[NotificationService] Background notification tapée | payload: ${response.payload}');
  }

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

  Future<void> scheduleHomeworkReminder({
    required String homeworkId,
    required String title,
    required DateTime deadline,
  }) async {
    final int notifId = _notificationIdFromHomeworkId(homeworkId);
    final DateTime now = DateTime.now();
    final DateTime reminderTime = deadline.subtract(const Duration(hours: 24));

    if (deadline.isBefore(now)) {
      print(
        '[NotificationService] Deadline passée pour "$title" → pas de rappel',
      );
      return;
    }

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

  Future<void> cancelNotification(int notificationId) async {
    await _localPlugin.cancel(notificationId);
    print('[NotificationService] Notification $notificationId annulée ✓');
  }

  Future<void> cancelHomeworkNotification(String homeworkId) async {
    final int notifId = _notificationIdFromHomeworkId(homeworkId);
    await cancelNotification(notifId);
    print(
      '[NotificationService] Rappel du devoir "$homeworkId" annulé ✓',
    );
  }

  Future<void> cancelAllNotifications() async {
    await _localPlugin.cancelAll();
    print('[NotificationService] Toutes les notifications annulées ✓');
  }

  int _notificationIdFromHomeworkId(String homeworkId) {
    return homeworkId.hashCode.abs() % 2147483647;
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours >= 1) {
      return '${duration.inHours}h${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}min';
    }
    return '${duration.inMinutes}min';
  }
}
