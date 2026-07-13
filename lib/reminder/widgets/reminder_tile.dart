import 'package:flutter/material.dart';
import '../reminder_model.dart';

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

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    int daysLeft = reminder.date.difference(now).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(.08),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Row(
            children: [

              // Event Icon
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
                      "${reminder.eventType} • ${reminder.relation}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [

                        const Icon(
                          Icons.calendar_today,
                          size: 15,
                          color: Colors.grey,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          "${reminder.date.day}/${reminder.date.month}/${reminder.date.year}",
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),

                        const SizedBox(width: 12),

                        const Icon(
                          Icons.access_time,
                          size: 15,
                          color: Colors.grey,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          reminder.time,
                          style: const TextStyle(
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                children: [

                  Switch(
                    value: reminder.notificationEnabled,
                    activeColor: const Color(0xffFF6B81),
                    onChanged: (_) {
                      if (onNotificationToggle != null) {
                        onNotificationToggle!();
                      }
                    },
                  ),

                  const SizedBox(height: 10),

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
                          ? "Passed"
                          : "$daysLeft Days",
                      style: const TextStyle(
                        color: Color(0xffFF6B81),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  PopupMenuButton(
                    itemBuilder: (context) => const [

                      PopupMenuItem(
                        value: "edit",
                        child: Text("Edit"),
                      ),

                      PopupMenuItem(
                        value: "delete",
                        child: Text("Delete"),
                      ),
                    ],

                    onSelected: (value) {

                      if (value == "delete") {
                        onDelete?.call();
                      }

                      if (value == "edit") {
                        // Future Edit Screen
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}