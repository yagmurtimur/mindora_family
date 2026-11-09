import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await android?.requestNotificationsPermission();

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();

    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'mindora_alerts',
        'Mindora Bildirimleri',
        description: 'Ekran süresi ve hedef hatırlatmaları',
        importance: Importance.high,
      ),
    );
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'mindora_alerts',
        'Mindora Bildirimleri',
        channelDescription: 'Ekran süresi ve hedef hatırlatmaları',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
