import 'reminder_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'reminder_model.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static const native = MethodChannel('yaadx/reminders');
  static void Function(String)? onReminderOpened;
  static String? pendingReminderId;

  static Future<bool> canScheduleExact() async =>
      await native.invokeMethod<bool>('canScheduleExact') ?? false;
  static Future<void> requestExact() =>
      native.invokeMethod<void>('requestExact');
  static Future<String?> takeLaunchReminder() async =>
      await native.invokeMethod<String>('takeLaunchReminder');

  /// Initializes local notifications and the device timezone.
  static Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();

    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneInfo.identifier));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const settings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.requestNotificationsPermission();

    native.setMethodCallHandler((call) async {
      if (call.method == 'openReminder' && call.arguments is String) {
        final id = call.arguments as String;
        await takeLaunchReminder();
        if (onReminderOpened != null) {
          onReminderOpened!(id);
        } else {
          pendingReminderId = id;
        }
      }
    });
    _initialized = true;
  }

  static Future<bool> alertsEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(
        ReminderService().alertsKey,
      ) ??
      true;

  static Future<bool> permissionGranted() async {
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  static Future<bool> requestPermission() async {
    await initialize();
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  static Future<void> setAlertsEnabled(bool enabled) async {
    await ReminderService().setAlertsPreference(enabled);
    if (!enabled) await cancelAll();
  }

  static Future<void> cancelAll() async {
    await native.invokeMethod<void>('cancelAll');
    await _plugin.cancelAll();
  }

  static Future<void> openSystemSettings() async {
    await const MethodChannel(
      'yaadx/settings',
    ).invokeMethod<void>('openNotificationSettings');
  }

  /// Schedules a notification for a saved reminder.
  static Future<void> scheduleReminder(ReminderModel reminder) async {
    await initialize();

    if (!await alertsEnabled() ||
        !reminder.notificationEnabled ||
        reminder.isCompleted) {
      await cancelReminder(reminder.id);
      return;
    }

    final event = reminder.eventDateTime;
    String? voiceUri;
    bool voiceFailed = false;
    if (reminder.voiceAlert) {
      try {
        voiceUri = await native.invokeMethod<String>('prepareVoice', {
          'text':
              "Tomorrow is ${reminder.name}'s ${reminder.eventType.toLowerCase()}.",
        });
        voiceFailed = voiceUri == null;
      } catch (_) {
        voiceFailed = true;
      }
    }
    await native.invokeMethod<void>('schedule', {
      'record': jsonEncode({
        'id': reminder.id,
        'name': reminder.name,
        'eventType': reminder.eventType,
        'note': reminder.note,
        'year': event.year,
        'month': event.month,
        'day': event.day,
        'hour': event.hour,
        'minute': event.minute,
        'yearly': reminder.repeatYearly,
        'advanceDays': reminder.voiceAlert && reminder.advanceDays == 0
            ? 1
            : reminder.advanceDays,
        'tomorrowVoiceUri': voiceUri ?? '',
      }),
    });
    await _plugin.cancel(id: _notificationId(reminder.id));
    if (voiceFailed) {
      throw StateError('Normal alert scheduled; voice preparation failed.');
    }
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
  static Future<void> shareMemoryForReminder(String reminderId) async {
    final reminderService = ReminderService();

    final ReminderModel? reminder = await reminderService.getReminderById(
      reminderId,
    );

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

  /// Generates a stable notification ID for a reminder.
  static int _notificationId(String reminderId) =>
      reminderId.hashCode & 0x7fffffff;

  /// Cancels the scheduled notification for a reminder.
  static Future<void> cancelReminder(String reminderId) async {
    await native.invokeMethod<void>('cancel', {'id': reminderId});
    await _plugin.cancel(id: _notificationId(reminderId));
  }
}
