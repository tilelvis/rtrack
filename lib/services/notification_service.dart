import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Local notification service — daily payment reminders.
///
/// Supports MULTIPLE reminder times (e.g. morning 08:00 + evening 19:00).
/// Each scheduled time has its own fixed notification id (1001, 1002, 1003...)
/// so it can be re-scheduled independently.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Persist the currently-scheduled reminder times so they survive app
  /// restarts. Stored as "HH:mm,HH:mm,...".
  ///
  /// Notification id for slot i = baseId + i.
  static const int _baseReminderId = 1001;
  static const int _maxReminders = 5;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    try {
      tz.setLocalLocation(tz.getLocation('Africa/Nairobi'));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) {},
    );

    const channel = AndroidNotificationChannel(
      'loan_tracker_daily',
      'Daily Payment Reminders',
      description: 'Daily reminders to make your loan payment',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a single daily reminder at [hour]:[minute] local time.
  /// Slot index [slotId] (0..4) — used to give each reminder a unique
  /// notification id so they can be managed independently.
  Future<void> scheduleDailyReminder({
    required int hour,
    required int minute,
    required String title,
    required String body,
    int slotId = 0,
  }) async {
    await init();
    final notifId = _baseReminderId + slotId.clamp(0, _maxReminders - 1);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      notifId,
      title,
      body,
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'loan_tracker_daily',
          'Daily Payment Reminders',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Schedule MULTIPLE daily reminders at the given times.
  /// All previously-scheduled reminders are cancelled first.
  Future<void> scheduleMultipleReminders({
    required List<ReminderTime> times,
    required String loanTitle,
    required double expectedAmount,
  }) async {
    await init();
    await cancelAll();
    for (var i = 0; i < times.length && i < _maxReminders; i++) {
      final t = times[i];
      await scheduleDailyReminder(
        hour: t.hour,
        minute: t.minute,
        title: 'Loan Tracker Reminder',
        body: loanTitle.isEmpty
            ? 'Remember to make your loan payment today.'
            : 'Pay Ksh ${expectedAmount.toStringAsFixed(0)} for "$loanTitle" today.',
        slotId: i,
      );
    }
  }

  /// Show an immediate test notification.
  Future<void> showTestNotification() async {
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'loan_tracker_daily',
        'Daily Payment Reminders',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      999,
      'Loan Tracker',
      'Notifications are working. You will be reminded daily.',
      details,
    );
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

/// A simple hour:minute container for reminder scheduling.
class ReminderTime {
  final int hour;
  final int minute;
  const ReminderTime({required this.hour, required this.minute});

  String format() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format as 12-hour with AM/PM, e.g. "8:00 AM" or "7:30 PM".
  String format12() {
    final period = hour < 12 ? 'AM' : 'PM';
    var h12 = hour % 12;
    if (h12 == 0) h12 = 12;
    return '$h12:${minute.toString().padLeft(2, '0')} $period';
  }

  @override
  String toString() => format();

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => hour.hashCode ^ minute.hashCode;
}
