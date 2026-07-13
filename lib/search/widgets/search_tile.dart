import 'package:flutter/material.dart';
import '../../reminder/reminder_model.dart';

class SearchTile extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback? onTap;

  const SearchTile({
    super.key,
    required this.reminder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: onTap,

        leading: CircleAvatar(
          backgroundColor: const Color(0xffFFE7E5),
          child: const Icon(
            Icons.celebration,
            color: Color(0xffF25F5C),
          ),
        ),

        title: Text(
          reminder.title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        subtitle: Text(
          reminder.relation,
        ),

        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
        ),
      ),
    );
  }
}