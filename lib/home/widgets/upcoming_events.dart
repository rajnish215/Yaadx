import 'package:flutter/material.dart';

class UpcomingEvents extends StatelessWidget {
  const UpcomingEvents({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        /// Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Upcoming Events",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            GestureDetector(
              onTap: () {},
              child: const Text(
                "View All >",
                style: TextStyle(
                  color: Color(0xffFF6B81), // Tumhara purana color maintain rakha hai
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        /// Timeline Items (Vertical)
        _buildTimelineItem(
          date: "20",
          month: "Jun",
          isActive: true, // First item ko active banaya (Red color)
          emoji: "🎂",
          title: "Pritam Birthday",
          category: "Birthday",
          categoryColor: const Color(0xffF25F5C),
          categoryBg: const Color(0xffFFE7E5),
          daysLeft: "10d",
          daysColor: const Color(0xffF25F5C),
          showLine: true,
        ),
        
        _buildTimelineItem(
          date: "28",
          month: "Jun",
          isActive: false,
          emoji: "💍",
          title: "Rahul",
          category: "Anniversary",
          categoryColor: const Color(0xff7C3AED),
          categoryBg: const Color(0xffF3E8FF),
          daysLeft: "18d",
          daysColor: const Color(0xff7C3AED),
          showLine: true,
        ),
        
        _buildTimelineItem(
          date: "05",
          month: "Jul",
          isActive: false,
          emoji: "🎉",
          title: "Ravi",
          category: "Celebration",
          categoryColor: const Color(0xff10B981),
          categoryBg: const Color(0xffD1FAE5),
          daysLeft: "25d",
          daysColor: const Color(0xff10B981),
          showLine: false, // Last item hai isliye line band kardi
        ),
      ],
    );
  }

  /// Naya Vertical Timeline Builder
  Widget _buildTimelineItem({
    required String date,
    required String month,
    required bool isActive,
    required String emoji,
    required String title,
    required String category,
    required Color categoryColor,
    required Color categoryBg,
    required String daysLeft,
    required Color daysColor,
    required bool showLine,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        /// Left Side: Date Box & Vertical Line
        Column(
          children: [
            Container(
              height: 62,
              width: 52,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xffC8453A) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isActive ? null : Border.all(color: const Color(0xffFFE7E5)),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: const Color(0xffC8453A).withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : const Color(0xffF25F5C),
                    ),
                  ),
                  Text(
                    month,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white70 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            
            // Connecting Vertical Line
            if (showLine)
              Container(
                height: 38, // Card ke beech ka gap
                width: 1.5,
                color: const Color(0xffFFE7E5),
              ),
          ],
        ),
        
        const SizedBox(width: 16),
        
        /// Right Side: Event Detail Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 22), 
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffFFE7E5), width: 1.2),
            ),
            child: Row(
              children: [
                
                // Emoji 
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                
                const SizedBox(width: 14),
                
                // Title and Badge
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: categoryBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Days Left Counter
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      daysLeft,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: daysColor,
                      ),
                    ),
                    const Text(
                      "left",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                
              ],
            ),
          ),
        ),
      ],
    );
  }
}