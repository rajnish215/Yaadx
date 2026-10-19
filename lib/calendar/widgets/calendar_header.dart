import 'package:flutter/material.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Menu Button
          Container(
            height: 50,
            width: 50,
            decoration: BoxDecoration(
              color: const Color(0xffFFF3F3),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.menu_rounded,
              color: Color(0xffF25C54),
              size: 26,
            ),
          ),

          // Title
          const Text(
            "Calendar",
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          // Right Side Icons
          Row(
            children: [
              _iconButton(Icons.search_rounded),
              const SizedBox(width: 12),
              _iconButton(Icons.tune_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon) {
    return Container(
      height: 50,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.black87,
        size: 24,
      ),
    );
  }
}