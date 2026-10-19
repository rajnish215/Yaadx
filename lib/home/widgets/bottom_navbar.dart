import 'package:flutter/material.dart';
import '../../reminder/add_reminder_screen.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: 100,
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 76,
            child: Material(
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _item(Icons.home_rounded, 'Home', 0),
                  _item(Icons.calendar_month, 'Calendar', 1),
                  const SizedBox(width: 60),
                  _item(Icons.notifications_none, 'Reminders', 2),
                  _item(Icons.person_outline, 'Profile', 3),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: FloatingActionButton(
              heroTag: 'mainAddReminder',
              tooltip: 'Add reminder',
              backgroundColor: const Color(0xffC8453A),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AddReminderScreen(),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _item(IconData icon, String label, int index) => InkWell(
    onTap: () => onTap(index),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: currentIndex == index
                ? const Color(0xffC8453A)
                : Colors.grey,
          ),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}
