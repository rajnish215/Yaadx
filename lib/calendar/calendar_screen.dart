
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../reminder/add_reminder_screen.dart';
import '../reminder/reminder_controller.dart';
import '../reminder/reminder_model.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  static const Color accent = Color(0xffC8453A);
  static const Color background = Color(0xffFFF8F6);

  late DateTime visibleMonth;
  late DateTime selectedDate;

  String selectedType = 'All';
  bool searching = false;

  final TextEditingController searchController =
      TextEditingController();

  final List<String> types = [
    'All',
    'Birthday',
    'Anniversary',
    'Meeting',
    'Festival',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    visibleMonth = DateTime(now.year, now.month);
    selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  String formatDate(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April',
      'May', 'June', 'July', 'August',
      'September', 'October', 'November', 'December',
    ];

    return months[month - 1];
  }

  IconData eventIcon(String type) {
    switch (type.toLowerCase()) {
      case 'birthday':
        return Icons.cake_outlined;
      case 'anniversary':
        return Icons.favorite_outline;
      case 'meeting':
        return Icons.groups_outlined;
      case 'festival':
        return Icons.celebration_outlined;
      default:
        return Icons.event_outlined;
    }
  }

  Future<void> openAddEvent(DateTime date) async {
    final controller = context.read<ReminderController>();

    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AddReminderScreen(
          selectedDate: DateTime(date.year, date.month, date.day),
        ),
      ),
    );

    if (!mounted) return;
    await controller.loadReminders();
  }

  List<ReminderModel> filteredEvents(
    List<ReminderModel> reminders,
    DateTime date,
  ) {
    final query = searchController.text.trim().toLowerCase();

    return reminders.where((event) {
      if (!sameDay(event.date, date)) return false;

      if (selectedType != 'All' &&
          event.eventType.toLowerCase() !=
              selectedType.toLowerCase()) {
        return false;
      }

      if (query.isNotEmpty &&
          !event.name.toLowerCase().contains(query) &&
          !event.eventType.toLowerCase().contains(query) &&
          !event.note.toLowerCase().contains(query)) {
        return false;
      }

      return true;
    }).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  int eventCount(List<ReminderModel> reminders, DateTime date) {
    return reminders.where((event) => sameDay(event.date, date)).length;
  }

  void changeMonth(int amount) {
    setState(() {
      visibleMonth = DateTime(
        visibleMonth.year,
        visibleMonth.month + amount,
      );
    });
  }

  void goToToday() {
    final now = DateTime.now();

    setState(() {
      visibleMonth = DateTime(now.year, now.month);
      selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  Future<void> deleteEvent(ReminderModel event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('Delete "${event.name}" from your calendar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await context.read<ReminderController>().deleteReminder(event.id);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event deleted')),
    );
  }

  void showEventDetails(ReminderModel event) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(26),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(
                    eventIcon(event.eventType),
                    color: accent,
                    size: 30,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      event.name,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              detailRow(Icons.event_outlined, 'Type', event.eventType),
              detailRow(
                Icons.calendar_today_outlined,
                'Date',
                formatDate(event.date),
              ),
              detailRow(
                Icons.access_time,
                'Time',
                event.time,
              ),
              detailRow(
                Icons.favorite_border,
                'Relation',
                event.relation,
              ),
              if (event.phoneNumber != null &&
                  event.phoneNumber!.trim().isNotEmpty)
                detailRow(
                  Icons.phone_outlined,
                  'Phone',
                  event.phoneNumber!,
                ),
              if (event.note.trim().isNotEmpty)
                detailRow(
                  Icons.notes_outlined,
                  'Note',
                  event.note,
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    deleteEvent(event);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete event'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: accent),
          const SizedBox(width: 12),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCalendar(List<ReminderModel> reminders) {
    final firstDay = DateTime(
      visibleMonth.year,
      visibleMonth.month,
      1,
    );

    final leadingDays = firstDay.weekday - 1;
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;

    final totalCells = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final today = DateTime.now();

    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];

    return Column(
      children: [
        Row(
          children: weekdays.map((day) {
            return Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: Colors.black45,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 5,
            crossAxisSpacing: 3,
            childAspectRatio: 0.76,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingDays + 1;

            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }

            final date = DateTime(
              visibleMonth.year,
              visibleMonth.month,
              day,
            );

            final isSelected = sameDay(date, selectedDate);
            final isToday = sameDay(date, today);
            final count = eventCount(reminders, date);

            return Material(
              color: isSelected ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  setState(() => selectedDate = date);
                  openAddEvent(date);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 31,
                      height: 31,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: isToday && !isSelected
                            ? Border.all(color: accent, width: 1.5)
                            : null,
                      ),
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected || isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    SizedBox(
                      height: 6,
                      child: count == 0
                          ? const SizedBox.shrink()
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                count > 3 ? 3 : count,
                                (_) => Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.white : accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];
          final selected = type == selectedType;

          return ChoiceChip(
            label: Text(type),
            selected: selected,
            showCheckmark: false,
            selectedColor: accent,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? accent : const Color(0xffF0DEDA),
            ),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            onSelected: (_) => setState(() => selectedType = type),
          );
        },
      ),
    );
  }

  Widget buildEventTile(ReminderModel event) {
    return InkWell(
      onTap: () => showEventDetails(event),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffF2E5E2)),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                eventIcon(event.eventType),
                color: accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${event.eventType} • ${event.relation}',
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                  if (event.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      event.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              event.time,
              style: const TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xffF2E5E2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_outlined,
            color: accent,
            size: 34,
          ),
          const SizedBox(height: 12),
          const Text(
            'No saved events on this date',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tap Add Event to save something important.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black54,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => openAddEvent(selectedDate),
            icon: const Icon(Icons.add),
            label: const Text('Add Event'),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              side: const BorderSide(color: accent),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderController>(
      builder: (context, controller, _) {
        final reminders = controller.reminders;
        final events = filteredEvents(reminders, selectedDate);

        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Your Calendar',
                              style: TextStyle(
                                fontSize: 25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${reminders.length} saved event(s)',
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Search events',
                        onPressed: () {
                          setState(() {
                            searching = !searching;
                            if (!searching) {
                              searchController.clear();
                            }
                          });
                        },
                        icon: Icon(
                          searching ? Icons.close : Icons.search,
                          color: accent,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Today',
                        onPressed: goToToday,
                        icon: const Icon(
                          Icons.today_outlined,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                  if (searching) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search name, type or note...',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xffF2E5E2),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => changeMonth(-1),
                              icon: const Icon(Icons.chevron_left),
                              color: accent,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    monthName(visibleMonth.month),
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${visibleMonth.year}',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => changeMonth(1),
                              icon: const Icon(Icons.chevron_right),
                              color: accent,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        buildCalendar(reminders),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Events',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              formatDate(selectedDate),
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => openAddEvent(selectedDate),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add Event'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  buildFilters(),
                  const SizedBox(height: 16),
                  if (events.isEmpty)
                    buildEmptyState()
                  else
                    ...events.map(buildEventTile),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
