import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();

  static const _channelId = 'daily_spending_channel';
  static const _paydayChannelId = 'payday_channel';
  static const _notificationId = 1;
  static const _paydayNotificationId = 2;

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleDailyNotification({
    required double dailyLimit,
    required String currencySymbol,
    int hour = 9,
    int minute = 0,
  }) async {
    await _plugin.cancel(_notificationId);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    final amount = dailyLimit < 0 ? 0 : dailyLimit;
    final formatted =
        '$currencySymbol${amount.toStringAsFixed(0)}';

    await _plugin.zonedSchedule(
      _notificationId,
      'Daily Spending Limit 💰',
      'You can spend up to $formatted today. Stay on track!',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily Spending Limit',
          channelDescription: 'Daily notification showing your spending limit',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> schedulePaydayNotification({
    required DateTime payday,
    int hour = 9,
    int minute = 0,
  }) async {
    await _plugin.cancel(_paydayNotificationId);

    final scheduled = tz.TZDateTime(
        tz.local, payday.year, payday.month, payday.day, hour, minute);
    final now = tz.TZDateTime.now(tz.local);

    if (scheduled.isBefore(now)) return; // Payday already passed

    await _plugin.zonedSchedule(
      _paydayNotificationId,
      'Payday! 🎉',
      'Your salary has arrived. Open the app to review your new budget.',
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _paydayChannelId,
          'Payday Notification',
          channelDescription: 'Notifies you when your salary arrives',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> showImmediateNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      3,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payday_channel',
          'Payday Notification',
          channelDescription: 'Notifies you when your salary arrives',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
