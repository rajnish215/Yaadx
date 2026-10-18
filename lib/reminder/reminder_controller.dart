
import 'package:flutter/material.dart';

import 'reminder_model.dart';
import 'reminder_service.dart';
import 'notification_service.dart';

class ReminderController extends ChangeNotifier {
  final ReminderService _service = ReminderService();

  List<ReminderModel> _reminders = [];

  List<ReminderModel> get reminders =>
      List.unmodifiable(_reminders);

  // Load reminders and restore their scheduled notifications.
  Future<void> loadReminders() async {
    _reminders = await _service.getReminders();

    for (final reminder in _reminders) {
      await NotificationService.scheduleReminder(reminder);
    }

    notifyListeners();
  }

  // Add reminder and schedule its notification.
  Future<void> addReminder(ReminderModel reminder) async {
    await _service.addReminder(reminder);
    await NotificationService.scheduleReminder(reminder);
    await loadReminders();
  }

  // Update reminder and reschedule its notification.
  Future<void> updateReminder(ReminderModel reminder) async {
    await _service.updateReminder(reminder);
    await NotificationService.scheduleReminder(reminder);
    await loadReminders();
  }

  // Delete reminder and cancel its notification.
  Future<void> deleteReminder(String id) async {
    await NotificationService.cancelReminder(id);
    await _service.deleteReminder(id);
    await loadReminders();
  }

  // Enable or disable a reminder notification.
  Future<void> toggleNotification(String id) async {
    final reminder = await _service.getReminderById(id);

    if (reminder == null) return;

    final updatedReminder = reminder.copyWith(
      notificationEnabled: !reminder.notificationEnabled,
    );

    await _service.updateReminder(updatedReminder);
    await NotificationService.scheduleReminder(updatedReminder);
    await loadReminders();
  }

  // Mark reminder completed and cancel its notification.
  Future<void> markCompleted(String id) async {
    final reminder = await _service.getReminderById(id);

    if (reminder == null) return;

    final updatedReminder = reminder.copyWith(
      isCompleted: true,
    );

    await _service.updateReminder(updatedReminder);
    await NotificationService.cancelReminder(id);
    await loadReminders();
  }

  // Delete all reminders and cancel their notifications.
  Future<void> clearAll() async {
    final existingReminders = await _service.getReminders();

    for (final reminder in existingReminders) {
      await NotificationService.cancelReminder(reminder.id);
    }

    await _service.clearAll();
    await loadReminders();
  }

  // Upcoming events.
  List<ReminderModel> get upcomingReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
      final eventDateTime = _eventDateTime(item);

      return eventDateTime.isAfter(now);
    }).toList()
      ..sort(
        (a, b) => _eventDateTime(a).compareTo(_eventDateTime(b)),
      );
  }

  // Today's events.
  List<ReminderModel> get todayReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
      return item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day;
    }).toList();
  }

  DateTime _eventDateTime(ReminderModel reminder) {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])$',
    ).firstMatch(reminder.time.trim());

    if (match == null) {
      return reminder.date;
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)!.toUpperCase();

    if (period == 'PM' && hour != 12) {
      hour += 12;
    } else if (period == 'AM' && hour == 12) {
      hour = 0;
    }

    return DateTime(
      reminder.date.year,
      reminder.date.month,
      reminder.date.day,
      hour,
      minute,
    );
  }

  // Total count.
  int get totalReminders => _reminders.length;
}
