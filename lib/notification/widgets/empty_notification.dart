import 'package:flutter/material.dart';

class EmptyNotification extends StatelessWidget {
  const EmptyNotification({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 120,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xffFFE7E5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 60,
              color: Color(0xffF25F5C),
            ),
          ),

          const SizedBox(height: 25),

          const Text(
            "No Notifications",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              "Your upcoming reminders and event alerts will appear here.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}