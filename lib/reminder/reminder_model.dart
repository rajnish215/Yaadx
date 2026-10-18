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
    this.notificationEnabled = true,
    this.isCompleted = false,
    required this.createdAt,
  });

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
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
