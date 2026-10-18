
import 'package:flutter/material.dart';

import '../../calendar/calendar_screen.dart';
import '../../reminder/add_reminder_screen.dart';
import '../../reminder/reminder_screen.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  void _openAddReminder(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddReminderScreen(),
      ),
    );
  }

  void _openCalendar(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CalendarScreen(),
      ),
    );
  }

  void _openReminders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReminderScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ActionCard(
                icon: Icons.add_circle_outline,
                title: 'Add',
                color: const Color(0xffFFE6E8),
                iconColor: const Color(0xffFF5A7A),
                onTap: () => _openAddReminder(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionCard(
                icon: Icons.calendar_month,
                title: 'Calendar',
                color: const Color(0xffE8EEFF),
                iconColor: const Color(0xff5B7FFF),
                onTap: () => _openCalendar(context),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ActionCard(
                icon: Icons.notifications_active_outlined,
                title: 'Reminders',
                color: const Color(0xffFFF2DD),
                iconColor: const Color(0xffF4A100),
                onTap: () => _openReminders(context),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: ActionCard(
                icon: Icons.card_giftcard,
                title: 'Gifts',
                color: Color(0xffE8F8F1),
                iconColor: Color(0xff28A86B),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color iconColor;
  final VoidCallback? onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 95,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
