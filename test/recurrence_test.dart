import 'package:flutter_test/flutter_test.dart';
import 'package:yaadx/reminder/reminder_model.dart';

ReminderModel yearly(int year, int month, int day) => ReminderModel(
  id: 'a',
  name: 'Test',
  relation: 'Friend',
  eventType: 'Birthday',
  date: DateTime(year, month, day),
  time: '18:30',
  note: '',
  repeatYearly: true,
  createdAt: DateTime(2026),
);
void main() {
  test(
    'yearly occurrence keeps local time and moves to next year after event',
    () {
      final event = yearly(2020, 10, 19);
      expect(
        event.nextOccurrence(DateTime(2026, 10, 19, 17)),
        DateTime(2026, 10, 19, 18, 30),
      );
      expect(
        event.nextOccurrence(DateTime(2026, 10, 19, 19)),
        DateTime(2027, 10, 19, 18, 30),
      );
    },
  );
  test('Feb 29 becomes Feb 28 only in non-leap years', () {
    final event = yearly(2024, 2, 29);
    expect(event.occurrenceInYear(2027), DateTime(2027, 2, 28, 18, 30));
    expect(event.occurrenceInYear(2028), DateTime(2028, 2, 29, 18, 30));
    expect(event.occursOn(DateTime(2027, 2, 28)), true);
    expect(event.occursOn(DateTime(2028, 2, 28)), false);
  });
  test('future starting year is respected', () {
    expect(
      yearly(2030, 1, 5).nextOccurrence(DateTime(2026)),
      DateTime(2030, 1, 5, 18, 30),
    );
    expect(yearly(2030, 1, 5).occursOn(DateTime(2027, 1, 5)), false);
  });
}
