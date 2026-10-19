import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/reminder/reminder_controller.dart';
import 'package:yaadx/reminder/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'fresh controller restores persisted reminders and sorts mixed time formats',
    () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
      SharedPreferences.setMockInitialValues({
        'yaadx_reminders': jsonEncode([
          for (final time in ['18:30', '9:05 AM', '12:00 PM'])
            {
              'id': time,
              'name': time,
              'relation': 'Friend',
              'eventType': 'Birthday',
              'date': date.toIso8601String(),
              'time': time,
              'note': '',
              'createdAt': DateTime.now().toIso8601String(),
            },
        ]),
      });
      final service = ReminderService();
      final scheduled = <String>[];
      final controller = ReminderController(
        scheduleReminder: (reminder) async => scheduled.add(reminder.id),
      );
      expect(controller.reminders, isEmpty);
      await controller.loadReminders();
      expect(controller.reminders, hasLength(3));
      expect(controller.upcomingReminders.map((r) => r.time), [
        '9:05 AM',
        '12:00 PM',
        '18:30',
      ]);
      expect(scheduled, hasLength(3));
      expect(controller.upcomingReminders.last.eventDateTime.hour, 18);
      controller.dispose();
      await service.clearAll();
    },
  );
}
