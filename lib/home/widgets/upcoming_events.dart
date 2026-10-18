
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../reminder/reminder_controller.dart';
import '../../reminder/reminder_model.dart';
import '../../reminder/reminder_screen.dart';

class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key});

  static const Color accent = Color(0xffC8453A);
  static const Color softBorder = Color(0xffFFE7E5);

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderController>(
      builder: (context, controller, child) {
        final events = controller.upcomingReminders.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Upcoming Events',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReminderScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xffFF6B81),
                    padding: EdgeInsets.zero,
                  ),
                  child: const Text(
                    'View All >',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (events.isEmpty)
              _buildEmptyState()
            else
              ...List.generate(events.length, (index) {
                final event = events[index];

                return _buildTimelineItem(
                  event: event,
                  isActive: index == 0,
                  showLine: index != events.length - 1,
                );
              }),
          ],
        );
      },
    );
  }

  Widget _buildTimelineItem({
    required ReminderModel event,
    required bool isActive,
    required bool showLine,
  }) {
    final categoryColor = _categoryColor(event.eventType);
    final categoryBg = categoryColor.withValues(alpha: 0.12);
    final daysLeft = _daysUntil(event.date);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date box and timeline line.
        SizedBox(
          width: 56,
          child: Column(
            children: [
              Container(
                height: 62,
                width: 52,
                decoration: BoxDecoration(
                  color: isActive ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isActive
                      ? null
                      : Border.all(color: softBorder),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      event.date.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isActive
                            ? Colors.white
                            : const Color(0xffF25F5C),
                      ),
                    ),
                    Text(
                      _monthName(event.date.month),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isActive ? Colors.white70 : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (showLine)
                Container(
                  height: 24,
                  width: 1.5,
                  color: softBorder,
                ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Event details.
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 22),
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: softBorder, width: 1.2),
            ),
            child: Row(
              children: [
                Text(
                  _eventEmoji(event.eventType),
                  style: const TextStyle(fontSize: 27),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: categoryBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.eventType,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${daysLeft}d',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: categoryColor,
                      ),
                    ),
                    const Text(
                      'left',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: softBorder),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 38,
            color: accent,
          ),
          SizedBox(height: 10),
          Text(
            'No Upcoming Events',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Add a reminder to see your upcoming events here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  int _daysUntil(DateTime date) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final eventDate = DateTime(date.year, date.month, date.day);

    return eventDate.difference(todayDate).inDays;
  }

  String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return months[month - 1];
  }

  Color _categoryColor(String type) {
    switch (type.toLowerCase()) {
      case 'birthday':
        return const Color(0xffF25F5C);
      case 'anniversary':
        return const Color(0xff7C3AED);
      case 'festival':
      case 'celebration':
        return const Color(0xff10B981);
      case 'meeting':
        return const Color(0xff5B7FFF);
      default:
        return const Color(0xffC8453A);
    }
  }

  String _eventEmoji(String type) {
    switch (type.toLowerCase()) {
      case 'birthday':
        return '🎂';
      case 'anniversary':
        return '💍';
      case 'festival':
      case 'celebration':
        return '🎉';
      case 'meeting':
        return '📅';
      default:
        return '🎁';
    }
  }
}
