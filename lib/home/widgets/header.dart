import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../search/search_screen.dart';
import '../../notification/notification_screen.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  String getCurrentDate() {
    return DateFormat('EEEE, d MMMM').format(DateTime.now());
  }

  String getGreeting() {
    final hour = DateTime.now().hour;

    if (hour < 12) {
      return "Good Morning";
    } else if (hour < 17) {
      return "Good Afternoon";
    } else {
      return "Good Evening";
    }
  }

  final String userName = "Bhavesh";

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date Chip
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xffFFE7E5),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 4,
                backgroundColor: Color(0xffFF6B6B),
              ),
              const SizedBox(width: 8),
              Text(
                getCurrentDate(),
                style: const TextStyle(
                  color: Color(0xffF25F5C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    getGreeting(),
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Hey, $userName 👋",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Row(
              children: [
                _circleButton(
                context,
                Icons.search,
                ),
                const SizedBox(width: 12),
                Stack(
                  children: [
                    _circleButton(
                      context,
                      Icons.notifications_none,
                    ),
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        height: 10,
                        width: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

static Widget _circleButton(
  BuildContext context,
  IconData icon,
) {
  return GestureDetector(

    onTap: () {
  if (icon == Icons.search) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SearchScreen(),
      ),
    );
  }

  if (icon == Icons.notifications_none) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationScreen(),
      ),
    );
  }
},

    child: Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: const Color(0xffF25F5C),
      ),
    ),
  );
}
}