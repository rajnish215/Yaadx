import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'add_reminder_screen.dart';
import 'reminder_controller.dart';
import 'widgets/empty_reminder.dart';
import 'widgets/reminder_tile.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReminderController>().loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {

    final controller = context.watch<ReminderController>();

    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),

      appBar: AppBar(
        backgroundColor: const Color(0xffFFF7F6),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
  color: Colors.black,
),

        title: const Text(
          "Reminders",
          style: TextStyle(
            color: Colors.black,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: controller.reminders.isEmpty

          ? const EmptyReminder()

          : ListView.builder(
              padding: const EdgeInsets.all(20),

              itemCount: controller.reminders.length,

              itemBuilder: (context, index) {

                final reminder =
                    controller.reminders[index];

                return ReminderTile(

                  reminder: reminder,

                  onTap: () {
                    // Future
                    // Open Reminder Details
                  },

                  onDelete: () async {

                    await controller.deleteReminder(
                      reminder.id,
                    );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Reminder Deleted",
                          ),
                        ),
                      );
                    }
                  },

                  onNotificationToggle: () async {

                    await controller
                        .toggleNotification(
                      reminder.id,
                    );
                  },
                );
              },
            ),

      floatingActionButton: FloatingActionButton.extended(

        backgroundColor: const Color(0xffC8453A),

        icon: const Icon(
          Icons.add,
          color: Colors.white,
        ),

        label: const Text(
          "Add Reminder",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        onPressed: () async {

          await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => const AddReminderScreen(),
  ),
);

if (context.mounted) {
  context.read<ReminderController>().loadReminders();
}
        },
      ),
    );
  }
}