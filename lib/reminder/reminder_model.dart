class ReminderModel {
  final String id;

  // Person Details
  final String name;
  final String relation;

  // Event Details
  final String eventType; // Birthday, Anniversary, Meeting, etc.
  final DateTime date;
  final String time;

  // Extra Details
  final String note;

  // Settings
  final bool notificationEnabled;
  final bool isCompleted;

  // Metadata
  final DateTime createdAt;

  ReminderModel({
    required this.id,
    required this.name,
    required this.relation,
    required this.eventType,
    required this.date,
    required this.time,
    required this.note,
    this.notificationEnabled = true,
    this.isCompleted = false,
    required this.createdAt,
  });

  ReminderModel copyWith({
    String? id,
    String? name,
    String? relation,
    String? eventType,
    DateTime? date,
    String? time,
    String? note,
    bool? notificationEnabled,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      eventType: eventType ?? this.eventType,
      date: date ?? this.date,
      time: time ?? this.time,
      note: note ?? this.note,
      notificationEnabled:
          notificationEnabled ?? this.notificationEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}