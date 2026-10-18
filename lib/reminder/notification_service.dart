
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';
import 'reminder_service.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const String _channelId = 'yaadx_reminders';
  static const String _channelName = 'YaadX Reminders';
  static const String _shareActionId = 'share_memory';

  /// Initializes local notifications and the device timezone.
  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Schedules a notification for a saved reminder.
  static Future<void> scheduleReminder(
    ReminderModel reminder,
  ) async {
    await initialize();

    await cancelReminder(reminder.id);

    if (!reminder.notificationEnabled || reminder.isCompleted) {
      return;
    }

    final scheduledDate = _getScheduledDate(reminder);

    // Do not schedule reminders for a past date/time.
    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Notifications for saved YaadX events',
      importance: Importance.max,
      priority: Priority.high,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          _shareActionId,
          'Send to ${reminder.name}',
          showsUserInterface: true,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.zonedSchedule(
      id: _notificationId(reminder.id),
      title: '${reminder.eventType}: ${reminder.name}',
      body: reminder.note.trim().isNotEmpty
          ? reminder.note.trim()
          : 'Your ${reminder.eventType.toLowerCase()} reminder is due.',
      scheduledDate: scheduledDate,
      notificationDetails: notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reminder.id,
    );
  }

  /// Handles notification taps and the "Send to..." action.
  static Future<void> _onNotificationResponse(
    NotificationResponse response,
  ) async {
    final reminderId = response.payload;

    if (reminderId == null || reminderId.isEmpty) {
      return;
    }

    // Both the notification body and its action open the share sheet.
    await shareMemoryForReminder(reminderId);
  }

  /// Shares saved photos with a caption or an event-based default message.
  static Future<void> shareMemoryForReminder(
    String reminderId,
  ) async {
    final reminderService = ReminderService();

    final ReminderModel? reminder =
        await reminderService.getReminderById(reminderId);

    if (reminder == null) {
      return;
    }

    final message = _createMessage(reminder);
    final photoPaths = <String>[];

    for (final path in reminder.memoryPhotoPaths) {
      if (await File(path).exists()) {
        photoPaths.add(path);
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        text: message,
        title: 'Send to ${reminder.name}',
        files: photoPaths.map((path) => XFile(path)).toList(),
      ),
    );
  }

  /// Message priority:
  /// 1. Memory caption, if provided.
  /// 2. Event-based default message, if the caption is empty.
  ///
  /// The reminder note is deliberately not used as the share message.
  static String _createMessage(ReminderModel reminder) {
    final caption = reminder.memoryCaption.trim();

    if (caption.isNotEmpty) {
      return caption;
    }

    switch (reminder.eventType.toLowerCase().trim()) {
      case 'birthday':
        return 'Happy Birthday, ${reminder.name}! 🎂🎉 '
            'Wishing you lots of happiness, success and beautiful '
            'moments. Have an amazing day! ❤️';

      case 'anniversary':
        return 'Happy Anniversary, ${reminder.name}! ❤️🎉 '
            'Wishing you lots of love, happiness and wonderful '
            'memories together.';

      case 'festival':
        return 'Wishing you a very happy festival, ${reminder.name}! '
            '🎉❤️';

      case 'meeting':
        return 'Hi ${reminder.name}! 😊 Just a reminder about our meeting.';

      default:
        return 'Hello ${reminder.name}! 😊 '
            'Just wanted to send you my best wishes. ❤️';
    }
  }

  /// Converts the reminder's saved date and time to local timezone.
  /// Supports formats such as 14:30, 2:30 PM and 9:05 AM.
  static tz.TZDateTime _getScheduledDate(
    ReminderModel reminder,
  ) {
    final time = reminder.time.trim();

    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$',
    ).firstMatch(time);

    if (match == null) {
      throw FormatException('Invalid reminder time: $time');
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();

    if (minute > 59) {
      throw FormatException('Invalid reminder minute: $time');
    }

    if (period != null) {
      if (hour < 1 || hour > 12) {
        throw FormatException('Invalid reminder hour: $time');
      }

      if (period == 'PM' && hour != 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
    } else if (hour > 23) {
      throw FormatException('Invalid reminder hour: $time');
    }

    final localDateTime = DateTime(
      reminder.date.year,
      reminder.date.month,
      reminder.date.day,
      hour,
      minute,
    );

    return tz.TZDateTime.from(localDateTime, tz.local);
  }

  /// Generates a stable notification ID for a reminder.
  static int _notificationId(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  /// Cancels the scheduled notification for a reminder.
  static Future<void> cancelReminder(
    String reminderId,
  ) async {
    await _plugin.cancel(id: _notificationId(reminderId));
  }
}
