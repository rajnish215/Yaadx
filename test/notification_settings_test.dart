import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/profile/notification_settings_screen.dart';
import 'package:yaadx/reminder/notification_service.dart';
import 'package:yaadx/reminder/reminder_controller.dart';
import 'package:yaadx/reminder/reminder_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <String>[];
  final nativeCalls = <MethodCall>[];
  bool allowed = true;
  bool voiceFailure = false;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    allowed = true;
    voiceFailure = false;
    calls.clear();
    nativeCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('yaadx/reminders'), (
          call,
        ) async {
          calls.add(call.method);
          nativeCalls.add(call);
          if (call.method == 'canScheduleExact') return true;
          if (call.method == 'prepareVoice') {
            if (voiceFailure) {
              throw PlatformException(code: 'voice_unavailable');
            }
            return 'content://voice/test.wav';
          }
          return null;
        });
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('flutter_timezone'),
      (_) async => 'Asia/Kolkata',
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('dexterous.com/flutter/local_notifications'),
      (call) async {
        calls.add(call.method);
        if (call.method == 'areNotificationsEnabled' ||
            call.method == 'requestNotificationsPermission') {
          return allowed;
        }
        return true;
      },
    );
    messenger.setMockMethodCallHandler(const MethodChannel('yaadx/settings'), (
      call,
    ) async {
      calls.add(call.method);
      return null;
    });
  });

  testWidgets(
    'master switch persists and phone settings opens; denied permission stays disabled',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => ReminderController(scheduleReminder: (_) async {}),
          child: const MaterialApp(home: NotificationSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await NotificationService.alertsEnabled(), false);
      expect(calls, contains('cancelAll'));
      await tester.tap(find.text('Open phone settings'));
      await tester.pumpAndSettle();
      expect(calls, contains('openNotificationSettings'));
      allowed = false;
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await NotificationService.alertsEnabled(), false);
      allowed = true;
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(await NotificationService.alertsEnabled(), true);
    },
  );

  test('disabled master preference prevents scheduling new events', () async {
    await NotificationService.initialize();
    await NotificationService.setAlertsEnabled(false);
    calls.clear();
    final reminder = ReminderModel(
      id: 'one',
      name: 'Test',
      relation: 'Friend',
      eventType: 'Birthday',
      date: DateTime.now().add(const Duration(days: 1)),
      time: '18:30',
      note: '',
      createdAt: DateTime.now(),
    );
    await NotificationService.scheduleReminder(reminder);
    expect(calls, contains('cancel'));
    expect(calls, isNot(contains('schedule')));
    await NotificationService.setAlertsEnabled(true);
    await NotificationService.scheduleReminder(reminder);
    expect(calls, contains('schedule'));
  });
  test('voice announces tomorrow and is removed when disabled', () async {
    final reminder = ReminderModel(
      id: 'tomorrow',
      name: 'Ankit',
      relation: 'Friend',
      eventType: 'Birthday',
      date: DateTime.now().add(const Duration(days: 2)),
      time: '18:30',
      note: '',
      createdAt: DateTime.now(),
      voiceAlert: true,
      advanceDays: 0,
    );
    await NotificationService.scheduleReminder(reminder);
    final speech = nativeCalls.singleWhere(
      (call) => call.method == 'prepareVoice',
    );
    expect(speech.arguments['text'], "Tomorrow is Ankit's birthday.");
    final schedule = nativeCalls.lastWhere((call) => call.method == 'schedule');
    final record = jsonDecode(schedule.arguments['record'] as String);
    expect(record['tomorrowVoiceUri'], 'content://voice/test.wav');
    expect(record.containsKey('voiceUri'), false);
    nativeCalls.clear();
    await NotificationService.scheduleReminder(
      reminder.copyWith(voiceAlert: false),
    );
    expect(nativeCalls.any((call) => call.method == 'prepareVoice'), false);
    final disabled = nativeCalls.lastWhere((call) => call.method == 'schedule');
    expect(
      jsonDecode(disabled.arguments['record'] as String)['tomorrowVoiceUri'],
      '',
    );
  });
  test(
    'voice failure still schedules a normal tomorrow and event-day alert',
    () async {
      voiceFailure = true;
      final event = ReminderModel(
        id: 'voice-fallback',
        name: 'Ankit',
        relation: 'Friend',
        eventType: 'Birthday',
        date: DateTime(2030, 11, 1),
        time: '18:30',
        note: '',
        createdAt: DateTime(2026),
        voiceAlert: true,
        advanceDays: 0,
      );
      await expectLater(
        NotificationService.scheduleReminder(event),
        throwsStateError,
      );
      final schedule = nativeCalls.singleWhere(
        (call) => call.method == 'schedule',
      );
      final record = jsonDecode(schedule.arguments['record'] as String) as Map;
      expect(record['tomorrowVoiceUri'], '');
      expect(record['advanceDays'], 1);
      expect(record['hour'], 18);
    },
  );
}
