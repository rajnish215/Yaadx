import 'dart:async';
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

  String? alertWarning;
  Future<void> _restoreAlert(ReminderModel reminder) async {
    try {
      await _scheduleReminder(reminder);
    } catch (_) {
      alertWarning =
          'Your events are saved. Some alerts could not be prepared. Check notification and voice settings, then retry.';
    }
  }

  int _session = 0;
  bool _disposed = false;
  Future<void>? _cloudLoad;
  Future<void> syncCloud() {
    if (!_service.cloudEnabled) return Future.value();
    if (_cloudLoad != null) return _cloudLoad!;
    final session = _session;
    _cloudLoad = (() async {
      await _service.sync();
      if (_disposed || session != _session) return;
      final updated = await _service.getReminders();
      if (_disposed || session != _session) return;
      for (final old in _reminders) {
        if (!updated.any((r) => r.id == old.id)) {
          await NotificationService.cancelReminder(old.id);
        }
      }
      _reminders = updated;
      alertWarning = null;
      for (final r in updated) {
        if (_disposed || session != _session) return;
        await _restoreAlert(r);
      }
      if (!_disposed && session == _session) notifyListeners();
    })().whenComplete(() => _cloudLoad = null);
    return _cloudLoad!;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // Load reminders and restore their scheduled notifications.
  Future<void> loadReminders() async {
    final session = _session;
    final loaded = await _service.getReminders();
    if (_disposed || session != _session) return;
    _reminders = loaded;
    alertWarning = null;
    for (final reminder in loaded) {
      if (_disposed || session != _session) return;
      await _restoreAlert(reminder);
    }
    if (_disposed || session != _session) return;
    notifyListeners();
    unawaited(syncCloud());
  }

  // Add reminder and schedule its notification.
  Future<void> addReminder(ReminderModel reminder) async {
    await _service.addReminder(reminder);
    await loadReminders();
  }

  // Update reminder and reschedule its notification.
  Future<void> updateReminder(ReminderModel reminder) async {
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
    _session++;
    alertWarning = null;
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

  ReminderModel? nextEventForHome(DateTime now) {
    final active = reminders
        .where(
          (r) =>
              !r.isCompleted &&
              (r.occursOn(now) || r.nextOccurrence(now).isAfter(now)),
        )
        .toList();
    DateTime occurrence(ReminderModel r) =>
        r.occursOn(now) ? r.occurrenceInYear(now.year) : r.nextOccurrence(now);
    active.sort((a, b) {
      final order = occurrence(a).compareTo(occurrence(b));
      return order == 0 ? a.id.compareTo(b.id) : order;
    });
    return active.isEmpty ? null : active.first;
  }

  // Total count.
  int get totalReminders => _reminders.length;
}
