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
  bool allowed = true;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    allowed = true;
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('yaadx/reminders'), (
          call,
        ) async {
          calls.add(call.method);
          if (call.method == 'canScheduleExact') return true;
          if (call.method == 'prepareVoice') return 'content://voice/test.wav';
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
}
