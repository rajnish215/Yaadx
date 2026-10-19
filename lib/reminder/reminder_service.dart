import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reminder_model.dart';

class ReminderService {
  // Singleton
  static final ReminderService _instance = ReminderService._internal();

  factory ReminderService() => _instance;

  ReminderService._internal();

  String _storageKey = 'yaadx_reminders';

  Future<void> useAccount(String? uid, {bool migrateLegacy = false}) async {
    final nextKey = uid == null ? 'yaadx_signed_out' : 'yaadx_reminders_$uid';
    if (migrateLegacy && uid != null) {
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString('yaadx_reminders');
      final legacyOwner = prefs.getString('yaadx_legacy_owner');
      if (legacy != null && legacyOwner == null) {
        if (!await prefs.setString('yaadx_legacy_owner', uid)) {
          throw StateError('Could not assign saved reminders.');
        }
      }
      if (legacy != null &&
          (legacyOwner == null || legacyOwner == uid) &&
          !prefs.containsKey(nextKey)) {
        if (!await prefs.setString(nextKey, legacy)) {
          throw StateError('Could not migrate saved reminders.');
        }
        await prefs.remove('yaadx_reminders');
      }
    }
    _storageKey = nextKey;
    _database.clear();
    _isLoaded = false;
  }

  // In-memory cache
  final List<ReminderModel> _database = [];

  bool _isLoaded = false;

  // Load reminders from persistent storage.
  Future<void> _loadFromStorage() async {
    if (_isLoaded) return;

    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString(_storageKey);

    _database.clear();

    if (savedData != null && savedData.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(savedData);

      _database.addAll(
        decoded.map(
          (item) => _fromJson(Map<String, dynamic>.from(item as Map)),
        ),
      );
    }

    _isLoaded = true;
  }

  // Save reminders to persistent storage.
  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final encoded = jsonEncode(_database.map(_toJson).toList());

    await prefs.setString(_storageKey, encoded);
  }

  // Convert reminder to JSON.
  Map<String, dynamic> _toJson(ReminderModel reminder) {
    return {
      'id': reminder.id,
      'name': reminder.name,
      'relation': reminder.relation,
      'phoneNumber': reminder.phoneNumber,
      'eventType': reminder.eventType,
      'date': reminder.date.toIso8601String(),
      'time': reminder.time,
      'note': reminder.note,

      // Photo memory fields
      'memoryPhotoPaths': reminder.memoryPhotoPaths,
      'memoryCaption': reminder.memoryCaption,

      // Voice note
      'voiceNotePath': reminder.voiceNotePath,

      // Event preparation checklist
      'voiceNoteCompleted': reminder.voiceNoteCompleted,
      'messageSent': reminder.messageSent,

      // Settings
      'repeatYearly': reminder.repeatYearly,
      'advanceDays': reminder.advanceDays,
      'voiceAlert': reminder.voiceAlert,
      'notificationEnabled': reminder.notificationEnabled,
      'isCompleted': reminder.isCompleted,

      // Metadata
      'createdAt': reminder.createdAt.toIso8601String(),
    };
  }

  // Convert JSON back to a reminder.
  // Defaults maintain compatibility with older saved reminders.
  ReminderModel _fromJson(Map<String, dynamic> json) {
    final savedPhotoPaths = json['memoryPhotoPaths'];

    return ReminderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      relation: json['relation'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      eventType: json['eventType'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      note: json['note'] as String? ?? '',

      // Photo memory fields
      memoryPhotoPaths: savedPhotoPaths is List
          ? savedPhotoPaths.whereType<String>().toList()
          : const [],
      memoryCaption: json['memoryCaption'] as String? ?? '',

      // Voice note
      voiceNotePath: json['voiceNotePath'] as String?,

      // Event preparation checklist
      voiceNoteCompleted: json['voiceNoteCompleted'] as bool? ?? false,
      messageSent: json['messageSent'] as bool? ?? false,

      // Settings
      repeatYearly: json['repeatYearly'] as bool? ?? false,
      advanceDays: (json['advanceDays'] as int? ?? 10).clamp(0, 10),
      voiceAlert: json['voiceAlert'] as bool? ?? false,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,

      // Metadata
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Get all reminders.
  Future<List<ReminderModel>> getReminders() async {
    await _loadFromStorage();
    return List<ReminderModel>.from(_database);
  }

  // Get reminder by ID.
  Future<ReminderModel?> getReminderById(String id) async {
    await _loadFromStorage();

    for (final reminder in _database) {
      if (reminder.id == id) {
        return reminder;
      }
    }

    return null;
  }

  // Add reminder.
  Future<void> addReminder(ReminderModel reminder) async {
    await _loadFromStorage();

    _database.add(reminder);
    await _saveToStorage();
  }

  // Update reminder.
  Future<void> updateReminder(ReminderModel reminder) async {
    await _loadFromStorage();

    final index = _database.indexWhere((item) => item.id == reminder.id);

    if (index != -1) {
      _database[index] = reminder;
      await _saveToStorage();
    }
  }

  // Delete reminder.
  Future<void> deleteReminder(String id) async {
    await _loadFromStorage();

    _database.removeWhere((item) => item.id == id);
    await _saveToStorage();
  }

  // Clear all reminders.
  Future<void> clearAll() async {
    await _loadFromStorage();

    _database.clear();
    await _saveToStorage();
  }
}
