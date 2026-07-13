import 'package:flutter/material.dart';

class BottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 85,
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 20, offset: Offset(0, -5))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(icon: Icons.home_rounded, title: "Home", index: 0),
              _buildNavItem(icon: Icons.calendar_month, title: "Calendar", index: 1),
              const SizedBox(width: 60),
              _buildNavItem(icon: Icons.notifications_none, title: "Reminders", index: 2),
              _buildNavItem(icon: Icons.person_outline, title: "Profile", index: 3),
            ],
          ),
        ),
        Positioned(
          top: -28, left: 0, right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () => print("Add Clicked"),
              child: Container(
                height: 60, width: 60,
                decoration: BoxDecoration(color: const Color(0xffC8453A), shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({required IconData icon, required String title, required int index}) {
    bool isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: isActive ? const Color(0xffC8453A) : Colors.grey),
            Text(title, style: TextStyle(fontSize: 12, color: isActive ? const Color(0xffC8453A) : Colors.grey)),
          ],
        ),
      ),
    );
  }
}