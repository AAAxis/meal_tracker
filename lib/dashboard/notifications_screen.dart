import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _requestNotificationPermissions();
    _scheduleDailyNotification();
  }

  Future<void> _requestNotificationPermissions() async {
    bool granted = true;
    // Android
    final androidPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
    if (androidPlugin != null) {
      final result = await androidPlugin.requestNotificationsPermission();
      if (result != null && result == false) granted = false;
    }
    // iOS
    final iosPlugin =
        flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
    if (iosPlugin != null) {
      final result = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      if (result != null && result == false) granted = false;
    }
    if (!granted && mounted) {
      setState(() {});
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text('notifications.disabled_title'.tr()),
              content: Text(
                'notifications.enable_prompt'.tr(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('common.ok'.tr()),
                ),
              ],
            ),
      );
    }
  }

  List<Map<String, String>> getNotifications() {
    // Use a static list of notifications (can be localized)
    return [
      {
        'title': 'notifications.get_started.title'.tr(),
        'subtitle': 'notifications.get_started.subtitle'.tr(),
      },
      {
        'title': 'notifications.first_meal.title'.tr(),
        'subtitle': 'notifications.first_meal.subtitle'.tr(),
      },
      {
        'title': 'notifications.three_days.title'.tr(),
        'subtitle': 'notifications.three_days.subtitle'.tr(),
      },
      {
        'title': 'notifications.five_meals.title'.tr(),
        'subtitle': 'notifications.five_meals.subtitle'.tr(),
      },
      {
        'title': 'notifications.ten_meals.title'.tr(),
        'subtitle': 'notifications.ten_meals.subtitle'.tr(),
      },
      {
        'title': 'notifications.keep_going.title'.tr(),
        'subtitle': 'notifications.keep_going.subtitle'.tr(),
      },
    ];
  }

  Future<void> _scheduleDailyNotification() async {
    final notifications = getNotifications();
    final random = Random();
    final notification = notifications[random.nextInt(notifications.length)];

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'daily_reminder_channel_id',
      'Daily Reminders',
      channelDescription: 'Daily meal logging reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Schedule for 7:00 PM local time
    final now = DateTime.now();
    final firstNotificationTime = DateTime(
      now.year,
      now.month,
      now.day,
      19, // 7 PM
      0,
    ).isAfter(now)
        ? DateTime(now.year, now.month, now.day, 19, 0)
        : DateTime(now.year, now.month, now.day + 1, 19, 0);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      notification['title'],
      notification['subtitle'],
      tz.TZDateTime.from(firstNotificationTime, tz.local),
      platformChannelSpecifics,
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = getNotifications();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Pick one notification per day
    final now = DateTime.now();
    final index = now.difference(DateTime(now.year)).inDays % notifications.length;
    final notification = notifications[index];

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text(
          'notifications.notifications'.tr(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: isDark ? Colors.black : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications,
                      size: 64,
                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'notifications.none_yet'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              )
            : ListTile(
                leading: Icon(
                  Icons.notifications,
                  size: 48,
                  color: Colors.grey[400],
                ),
                title: Text(
                  notification['title'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                subtitle: Text(
                  notification['subtitle'] ?? '',
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
      ),
    );
  }
}
