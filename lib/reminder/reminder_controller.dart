import 'package:flutter/material.dart';

import 'reminder_model.dart';
import 'reminder_service.dart';

class ReminderController extends ChangeNotifier {
  final ReminderService _service = ReminderService();

  List<ReminderModel> _reminders = [];

  List<ReminderModel> get reminders =>
      List.unmodifiable(_reminders);

  // Load All Reminders
  Future<void> loadReminders() async {
    _reminders = await _service.getReminders();
    notifyListeners();
  }

  // Add Reminder
  Future<void> addReminder(
    ReminderModel reminder,
  ) async {
    await _service.addReminder(reminder);
    await loadReminders();
  }

  // Update Reminder
  Future<void> updateReminder(
    ReminderModel reminder,
  ) async {
    await _service.updateReminder(reminder);
    await loadReminders();
  }

  // Delete Reminder
  Future<void> deleteReminder(
    String id,
  ) async {
    await _service.deleteReminder(id);
    await loadReminders();
  }

  // Toggle Notification
  Future<void> toggleNotification(
    String id,
  ) async {
    final reminder = await _service.getReminderById(id);

    if (reminder == null) return;

    await _service.updateReminder(
      reminder.copyWith(
        notificationEnabled:
            !reminder.notificationEnabled,
      ),
    );

    await loadReminders();
  }

  // Mark Completed
  Future<void> markCompleted(
    String id,
  ) async {
    final reminder = await _service.getReminderById(id);

    if (reminder == null) return;

    await _service.updateReminder(
      reminder.copyWith(
        isCompleted: true,
      ),
    );

    await loadReminders();
  }

  // Clear All
  Future<void> clearAll() async {
    await _service.clearAll();
    await loadReminders();
  }

  // Upcoming Events
  List<ReminderModel> get upcomingReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
      return item.date.isAfter(now);
    }).toList()
      ..sort(
        (a, b) => a.date.compareTo(b.date),
      );
  }

  // Today's Events
  List<ReminderModel> get todayReminders {
    final now = DateTime.now();

    return _reminders.where((item) {
      return item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day;
    }).toList();
  }

  // Total Count
  int get totalReminders =>
      _reminders.length;
}