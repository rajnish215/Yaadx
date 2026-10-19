import 'package:flutter/material.dart';

import '../reminder_model.dart';
import '../add_reminder_screen.dart';
import '../celebrate_screen.dart';
import '../notification_service.dart';

class ReminderTile extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onNotificationToggle;

  const ReminderTile({
    super.key,
    required this.reminder,
    this.onTap,
    this.onDelete,
    this.onNotificationToggle,
  });

  Future<void> _shareMemory(BuildContext context) async {
    try {
      await NotificationService.shareMemoryForReminder(reminder.id);
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open sharing options. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    final occurrence = reminder.repeatYearly && reminder.occursOn(now)
        ? reminder.occurrenceInYear(now.year)
        : reminder.nextOccurrence(now);
    final eventDay = DateTime(
      occurrence.year,
      occurrence.month,
      occurrence.day,
    );

    final today = DateTime(now.year, now.month, now.day);
    final daysLeft = eventDay.difference(today).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CelebrateScreen(reminderId: reminder.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xffFFE8EC),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.celebration,
                      color: Color(0xffFF6B81),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${reminder.eventType} • ${reminder.relation}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${occurrence.day}/${occurrence.month}/${occurrence.year}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reminder.time,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Switch(
                        value: reminder.notificationEnabled,
                        activeThumbColor: const Color(0xffFF6B81),
                        onChanged: (_) {
                          onNotificationToggle?.call();
                        },
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xffFFF3F5),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          daysLeft < 0
                              ? 'Passed'
                              : daysLeft == 0
                              ? 'Today'
                              : '$daysLeft Days',
                          style: const TextStyle(
                            color: Color(0xffFF6B81),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                        onSelected: (value) {
                          if (value == 'delete') {
                            onDelete?.call();
                          } else if (value == 'edit') {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    AddReminderScreen(reminder: reminder),
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _shareMemory(context),
                  icon: const Icon(Icons.share, color: Colors.white),
                  label: const Text(
                    'Share Memory',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff25D366),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
