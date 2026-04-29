import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class PushNotificationService {
  static int _id = 100; // start above 0 to avoid clash with alarm IDs

  static Future<void> init() async {
    await AwesomeNotifications().initialize(
      null, // use the default app icon
      [
        NotificationChannel(
          channelKey: 'messages',
          channelName: 'Messages',
          channelDescription: 'Nouveaux messages de chat',
          defaultColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'comments',
          channelName: 'Commentaires',
          channelDescription: 'Nouveaux commentaires sur vos annonces',
          defaultColor: Colors.purple,
          importance: NotificationImportance.Default,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'requests',
          channelName: 'Demandes',
          channelDescription: 'Nouvelles demandes de travaux',
          defaultColor: Colors.orange,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'status',
          channelName: 'Mises à jour',
          channelDescription: 'Changements de statut de vos demandes',
          defaultColor: Colors.green,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
      debug: false,
    );
  }

  static Future<void> requestPermission() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (!allowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  }

  static Future<void> showMessage({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _id++,
        channelKey: 'messages',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Message,
      ),
    );
  }

  static Future<void> showComment({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _id++,
        channelKey: 'comments',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Social,
      ),
    );
  }

  static Future<void> showRequest({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _id++,
        channelKey: 'requests',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
      ),
    );
  }

  static Future<void> showStatusUpdate({
    required String title,
    required String body,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: _id++,
        channelKey: 'status',
        title: title,
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Status,
      ),
    );
  }
}
