import 'package:flutter/material.dart';

class TaskSection extends StatelessWidget {
  const TaskSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        
        /// Header Row (Title + 50% Tag)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Today's Tasks",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xffFFE7E5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                "50%",
                style: TextStyle(
                  color: Color(0xffF25F5C),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            )
          ],
        ),

        const SizedBox(height: 16),

        /// Global Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: 0.5, // 50% Progress
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation(
              Color(0xffF25F5C),
            ),
          ),
        ),

        const SizedBox(height: 24),

        /// Checklist Container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xffFFE7E5), // Faint pinkish border
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              _buildTaskItem("Order Puja's birthday cake", true),
              _buildDivider(),
              _buildTaskItem("Book The Romantic Bistro", true),
              _buildDivider(),
              _buildTaskItem("Buy anniversary gift for parents", false),
              _buildDivider(),
              _buildTaskItem("Send voice note to Rahul", false),
            ],
          ),
        ),
      ],
    );
  }

  /// Task Item Builder
  Widget _buildTaskItem(String title, bool isCompleted) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_outline : Icons.radio_button_unchecked,
            color: isCompleted ? const Color(0xffF25F5C) : Colors.grey.shade400,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                // Completed hai to grey color aur line-through (strikethrough)
                color: isCompleted ? Colors.grey.shade500 : Colors.black87,
                decoration: isCompleted 
                    ? TextDecoration.lineThrough 
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Divider between tasks
  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: const Color(0xffFFE7E5).withOpacity(0.5),
      indent: 18, // Line ko thoda left se start karne ke liye
      endIndent: 18,
    );
  }
}