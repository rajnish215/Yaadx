import 'reminder_model.dart';

class ReminderService {

  // Singleton
  static final ReminderService _instance =
      ReminderService._internal();

  factory ReminderService() => _instance;

  ReminderService._internal();

  final List<ReminderModel> _database = [];

  // Get All
  Future<List<ReminderModel>> getReminders() async {
    return List.from(_database);
  }

  // Get By Id
  Future<ReminderModel?> getReminderById(
    String id,
  ) async {
    try {
      return _database.firstWhere(
        (item) => item.id == id,
      );
    } catch (_) {
      return null;
    }
  }

  // Add
  Future<void> addReminder(
    ReminderModel reminder,
  ) async {
    _database.add(reminder);
  }

  // Update
  Future<void> updateReminder(
    ReminderModel reminder,
  ) async {
    final index = _database.indexWhere(
      (item) => item.id == reminder.id,
    );

    if (index != -1) {
      _database[index] = reminder;
    }
  }

  // Delete
  Future<void> deleteReminder(
    String id,
  ) async {
    _database.removeWhere(
      (item) => item.id == id,
    );
  }

  // Clear
  Future<void> clearAll() async {
    _database.clear();
  }
}