import 'package:flutter/material.dart';

class EmptyReminder extends StatelessWidget {
  const EmptyReminder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 30,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Container(
              height: 150,
              width: 150,
              decoration: BoxDecoration(
                color: const Color(0xffFFE8EC),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(
                Icons.notifications_active_outlined,
                size: 70,
                color: Color(0xffFF6B81),
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "No Reminders Yet",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xff2E2E2E),
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              "Stay organized by creating reminders for birthdays, anniversaries and all your important moments.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: const Color(0xffFFF5F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Icon(
                    Icons.lightbulb_outline,
                    color: Color(0xffFFB703),
                  ),

                  SizedBox(width: 10),

                  Text(
                    "Tap + to create your first reminder",
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
