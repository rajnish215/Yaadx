import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Quick Actions",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        
        const SizedBox(height: 18),

        // FIX: Saare cards ab ek hi Row mein hain
        Row(
          children: const [
            Expanded(
              child: ActionCard(
                icon: Icons.add_circle_outline,
                title: "Add", // Text thoda chota kiya taaki fit ho
                color: Color(0xffFFE6E8),
                iconColor: Color(0xffFF5A7A),
              ),
            ),
            SizedBox(width: 8), // Spacing kam ki hai
            Expanded(
              child: ActionCard(
                icon: Icons.calendar_month,
                title: "Calendar",
                color: Color(0xffE8EEFF),
                iconColor: Color(0xff5B7FFF),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ActionCard(
                icon: Icons.notifications_active_outlined,
                title: "Reminders",
                color: Color(0xffFFF2DD),
                iconColor: Color(0xffF4A100),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ActionCard(
                icon: Icons.card_giftcard,
                title: "Gifts", // Text adjust kiya taaki break na ho
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

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.color,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 95, // Height kam ki taaki 4 items ke sath proportionate lage
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20), // Radius thoda kam kiya
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
            height: 40, // Icon container chota kiya
            width: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 22, // Icon size reduce kiya
            ),
          ),
          
          const SizedBox(height: 10), // Spacing reduce ki
          
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 11, // Font size chota kiya taaki single line me aaye
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // Agar text bada ho to "..." aa jaye
          ),
        ],
      ),
    );
  }
}