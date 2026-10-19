import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/reminder/reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'legacy data migrates once and account switching isolates saved reminders',
    () async {
      SharedPreferences.setMockInitialValues({
        'yaadx_reminders': jsonEncode([
          {
            'id': 'one',
            'name': 'Private event',
            'relation': 'Friend',
            'eventType': 'Birthday',
            'date': '2030-01-01T00:00:00.000',
            'time': '18:30',
            'createdAt': '2026-01-01T00:00:00.000',
          },
        ]),
      });
      final service = ReminderService();
      await service.useAccount('alice', migrateLegacy: true);
      expect((await service.getReminders()).single.name, 'Private event');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('yaadx_reminders'), false);
      await service.useAccount(null);
      expect(await service.getReminders(), isEmpty);
      await service.useAccount('bob', migrateLegacy: true);
      expect(await service.getReminders(), isEmpty);
      await service.useAccount('alice');
      expect((await service.getReminders()).single.name, 'Private event');
    },
  );
}
