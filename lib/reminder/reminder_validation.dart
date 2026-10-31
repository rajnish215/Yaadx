import 'reminder_model.dart';

/// Match the API limits before writing a new local mutation.
class ReminderValidation {
  static const maxName = 120;
  static const maxText = 4000;
  static const maxPhotos = 10;

  static String? textError(
    String value,
    int limit,
    String label, {
    bool required = false,
  }) {
    final trimmed = value.trim();
    if (required && trimmed.isEmpty) return 'Please enter $label.';
    if (value.length > limit) {
      return '$label must be $limit characters or fewer.';
    }
    return null;
  }

  static void check(ReminderModel reminder) {
    final error =
        textError(reminder.name, maxName, 'Name', required: true) ??
        textError(reminder.note, maxText, 'Note') ??
        textError(reminder.memoryCaption, maxText, 'Caption') ??
        textError(reminder.relation, 80, 'Relation') ??
        textError(reminder.eventType, 80, 'Event type', required: true) ??
        textError(reminder.phoneNumber ?? '', 30, 'Phone number');
    if (error != null) throw FormatException(error);
    if (reminder.memoryPhotoPaths.length > maxPhotos) {
      throw const FormatException('Choose up to 10 photos per event.');
    }
    if (reminder.advanceDays < 0 || reminder.advanceDays > 10) {
      throw const FormatException(
        'Advance reminders must be between 0 and 10 days.',
      );
    }
    reminder.eventDateTime; // Validate both legacy and 24-hour values.
  }
}
