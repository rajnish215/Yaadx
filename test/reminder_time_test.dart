import 'package:flutter_test/flutter_test.dart';
import 'package:yaadx/reminder/reminder_model.dart';

ReminderModel event(String time) => ReminderModel(
  id: time,
  name: 'Test',
  relation: 'Friend',
  eventType: 'Birthday',
  date: DateTime(2030, 5, 20),
  time: time,
  note: '',
  createdAt: DateTime(2030),
);

void main() {
  for (final entry in {
    '18:30': [18, 30],
    '6:30 PM': [18, 30],
    ' 6:30 pm ': [18, 30],
    '00:00': [0, 0],
    '12:00 AM': [0, 0],
    '12:00 PM': [12, 0],
    '9:05 AM': [9, 5],
    '23:59': [23, 59],
  }.entries) {
    test('parses ${entry.key} without losing date or time', () {
      expect(
        event(entry.key).eventDateTime,
        DateTime(2030, 5, 20, entry.value[0], entry.value[1]),
      );
    });
  }
  for (final time in ['24:00', '12:60', '00:30 PM', '13:30 AM', 'invalid']) {
    test('rejects $time instead of silently using midnight', () {
      expect(() => event(time).eventDateTime, throwsFormatException);
    });
  }
}
