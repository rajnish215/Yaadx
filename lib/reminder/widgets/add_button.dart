import 'package:flutter/material.dart';

class AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final IconData icon;

  const AddButton({
    super.key,
    required this.onTap,
    this.title = "Add Reminder",
    this.icon = Icons.add,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          elevation: 3,
          backgroundColor: const Color(0xffFF6B81),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}