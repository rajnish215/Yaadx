class ReminderModel {
  final String id;

  // Person Details
  final String name;
  final String relation;
  final String? phoneNumber;

  // Event Details
  final String eventType;
  final DateTime date;
  final String time;

  // Extra Details
  final String note;

  // Photo Memories
  final List<String> memoryPhotoPaths;
  final String memoryCaption;

  // Voice Note
  final String? voiceNotePath;

  // Event Preparation Checklist
  final bool voiceNoteCompleted;
  final bool messageSent;

  // Settings
  final bool repeatYearly;
  final int advanceDays;
  final bool voiceAlert;
  final bool notificationEnabled;
  final bool isCompleted;

  // Metadata
  final DateTime createdAt;

  ReminderModel({
    required this.id,
    required this.name,
    required this.relation,
    this.phoneNumber,
    required this.eventType,
    required this.date,
    required this.time,
    required this.note,
    this.memoryPhotoPaths = const [],
    this.memoryCaption = '',
    this.voiceNotePath,
    this.voiceNoteCompleted = false,
    this.messageSent = false,
    this.repeatYearly = false,
    this.advanceDays = 10,
    this.voiceAlert = false,
    this.notificationEnabled = true,
    this.isCompleted = false,
    required this.createdAt,
  });

  /// The local event time, supporting existing 12-hour and 24-hour values.
  DateTime get eventDateTime {
    final match = RegExp(
      r'^(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?$',
    ).firstMatch(time.trim());
    if (match == null) {
      throw FormatException('Invalid reminder time: $time');
    }

    var hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final period = match.group(3)?.toUpperCase();
    if (minute > 59 || (period == null ? hour > 23 : hour < 1 || hour > 12)) {
      throw FormatException('Invalid reminder time: $time');
    }
    if (period != null) {
      hour = hour % 12 + (period == 'PM' ? 12 : 0);
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  DateTime occurrenceInYear(int year) {
    final original = eventDateTime;
    final lastDay = DateTime(year, date.month + 1, 0).day;
    return DateTime(
      year,
      date.month,
      date.day > lastDay ? lastDay : date.day,
      original.hour,
      original.minute,
    );
  }

  DateTime nextOccurrence(DateTime now) {
    if (!repeatYearly) return eventDateTime;
    var year = now.year < date.year ? date.year : now.year;
    var next = occurrenceInYear(year);
    if (!next.isAfter(now)) next = occurrenceInYear(++year);
    return next;
  }

  bool occursOn(DateTime day) {
    if (day.year < date.year) return false;
    final occurrence = repeatYearly
        ? occurrenceInYear(day.year)
        : eventDateTime;
    return occurrence.year == day.year &&
        occurrence.month == day.month &&
        occurrence.day == day.day;
  }

  ReminderModel copyWith({
    String? id,
    String? name,
    String? relation,
    String? phoneNumber,
    String? eventType,
    DateTime? date,
    String? time,
    String? note,
    List<String>? memoryPhotoPaths,
    String? memoryCaption,
    String? voiceNotePath,
    bool? voiceNoteCompleted,
    bool? messageSent,
    bool? repeatYearly,
    int? advanceDays,
    bool? voiceAlert,
    bool? notificationEnabled,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      eventType: eventType ?? this.eventType,
      date: date ?? this.date,
      time: time ?? this.time,
      note: note ?? this.note,
      memoryPhotoPaths: memoryPhotoPaths ?? this.memoryPhotoPaths,
      memoryCaption: memoryCaption ?? this.memoryCaption,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
      voiceNoteCompleted: voiceNoteCompleted ?? this.voiceNoteCompleted,
      messageSent: messageSent ?? this.messageSent,
      repeatYearly: repeatYearly ?? this.repeatYearly,
      advanceDays: advanceDays ?? this.advanceDays,
      voiceAlert: voiceAlert ?? this.voiceAlert,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
