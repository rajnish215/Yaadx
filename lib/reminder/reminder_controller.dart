import 'package:flutter/material.dart';

import 'reminder_model.dart';
import 'reminder_service.dart';
import 'notification_service.dart';

class ReminderController extends ChangeNotifier {
  ReminderController({Future<void> Function(ReminderModel)? scheduleReminder})
    : _scheduleReminder =
          scheduleReminder ?? NotificationService.scheduleReminder;

  final ReminderService _service = ReminderService();
  final Future<void> Function(ReminderModel) _scheduleReminder;

  List<ReminderModel> _reminders = [];

  List<ReminderModel> get reminders => List.unmodifiable(_reminders);

  // Load reminders and restore their scheduled notifications.
  Future<void> loadReminders() async {
    _reminders = await _service.getReminders();

    for (final reminder in _reminders) {
      await _scheduleReminder(reminder);
    }

    notifyListeners();
  }

  // Add reminder and schedule its notification.
  Future<void> addReminder(ReminderModel reminder) async {
    await _scheduleReminder(reminder);
    await _service.addReminder(reminder);
    await loadReminders();
  }

  // Update reminder and reschedule its notification.
  Future<void> updateReminder(ReminderModel reminder) async {
    await _scheduleReminder(reminder);
    await _service.updateReminder(reminder);
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
    await _scheduleReminder(updatedReminder);
    await loadReminders();
  }

  // Mark reminder completed and cancel its notification.
  Future<void> markCompleted(String id) async {
    final reminder = await _service.getReminderById(id);

    if (reminder == null) return;

    final updatedReminder = reminder.copyWith(isCompleted: true);

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

  void resetSession() {
    _reminders = [];
    notifyListeners();
  }

  // Upcoming events.
  List<ReminderModel> get upcomingReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
        final eventDateTime = item.nextOccurrence(now);

        return !item.isCompleted && eventDateTime.isAfter(now);
      }).toList()
      ..sort((a, b) => a.nextOccurrence(now).compareTo(b.nextOccurrence(now)));
  }

  // Today's events.
  List<ReminderModel> get todayReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
      return !item.isCompleted && item.occursOn(now);
    }).toList();
  }

  // Total count.
  int get totalReminders => _reminders.length;
}
