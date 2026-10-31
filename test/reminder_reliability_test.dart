import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/reminder/reminder_controller.dart';
import 'package:yaadx/reminder/reminder_model.dart';
import 'package:yaadx/reminder/reminder_service.dart';

ReminderModel event(String id) => ReminderModel(
  id: id,
  name: 'Ankit',
  relation: 'Friend',
  eventType: 'Birthday',
  date: DateTime(2030, 11, 1),
  time: '18:30',
  note: '',
  createdAt: DateTime(2026),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ReminderService();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    service.cloud = null;
    await service.useAccount('reliability');
  });
  test(
    'one broken alert does not hide saved events or stop other alerts',
    () async {
      await service.addReminder(event('broken'));
      await service.addReminder(event('working'));
      final calls = <String>[];
      final controller = ReminderController(
        scheduleReminder: (r) async {
          calls.add(r.id);
          if (r.id == 'broken') throw StateError('TTS unavailable');
        },
      );
      await controller.loadReminders();
      expect(controller.reminders, hasLength(2));
      expect(calls, ['broken', 'working']);
      expect(controller.alertWarning, isNotNull);
      controller.dispose();
    },
  );
  test(
    'new event remains saved when scheduling fails; retry clears warning',
    () async {
      bool fail = true;
      final controller = ReminderController(
        scheduleReminder: (_) async {
          if (fail) throw StateError('TTS');
        },
      );
      await controller.addReminder(event('new'));
      expect(await service.getReminderById('new'), isNotNull);
      expect(controller.alertWarning, isNotNull);
      fail = false;
      await controller.loadReminders();
      expect(controller.alertWarning, isNull);
      controller.dispose();
    },
  );
  test(
    'invalid edits preserve the existing reminder and valid limit values save',
    () async {
      await service.addReminder(event('same'));
      for (final invalid in [
        event('same').copyWith(name: 'x' * 121),
        event('same').copyWith(note: 'x' * 4001),
        event('same').copyWith(memoryCaption: 'x' * 4001),
        event(
          'same',
        ).copyWith(memoryPhotoPaths: List.generate(11, (i) => '/photo$i.jpg')),
      ]) {
        await expectLater(
          service.updateReminder(invalid),
          throwsFormatException,
        );
        expect((await service.getReminderById('same'))!.name, 'Ankit');
      }
      await service.updateReminder(
        event('same').copyWith(
          name: 'x' * 120,
          note: 'x' * 4000,
          memoryCaption: 'x' * 4000,
          memoryPhotoPaths: List.generate(10, (i) => '/photo$i.jpg'),
        ),
      );
      expect(
        (await service.getReminderById('same'))!.memoryPhotoPaths,
        hasLength(10),
      );
    },
  );
}
