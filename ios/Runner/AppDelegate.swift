// ios/Runner/AppDelegate.swift
// ─────────────────────────────────────────────────────────────────────────────
// TÂCHE 3 : Configuration iOS pour FCM + flutter_local_notifications
// ─────────────────────────────────────────────────────────────────────────────

import Flutter
import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── 1. Configurer Firebase ────────────────────────────────────────
        FirebaseApp.configure()

        // ── 2. Déléguer les notifications à cet AppDelegate ───────────────
        UNUserNotificationCenter.current().delegate = self

        // ── 3. Déléguer FCM à cet AppDelegate ────────────────────────────
        Messaging.messaging().delegate = self

        // ── 4. Enregistrer pour les notifications distantes ───────────────
        application.registerForRemoteNotifications()

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    // ── Recevoir le token APNs et l'envoyer à FCM ─────────────────────────
    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    // ── Gérer l'échec d'enregistrement ───────────────────────────────────
    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Échec enregistrement notifications : \(error.localizedDescription)")
    }

    // ── Afficher les notifications en FOREGROUND (iOS 10+) ────────────────
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Afficher banner + son même si l'app est en foreground
        completionHandler([.banner, .badge, .sound])
    }

    // ── L'utilisateur a tapé sur une notification ─────────────────────────
    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        print("[AppDelegate] Notification tapée : \(userInfo)")
        Messaging.messaging().appDidReceiveMessage(userInfo)
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// Extension FCM Messaging Delegate
// ─────────────────────────────────────────────────────────────────────────────
extension AppDelegate: MessagingDelegate {

    // Reçoit le token FCM (renouvelé automatiquement)
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("[AppDelegate] FCM Token : \(fcmToken ?? "nil")")
        // TODO : envoyer le token vers Firestore pour les push ciblés
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
}