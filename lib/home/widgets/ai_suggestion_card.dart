import 'package:flutter/material.dart';

class AiSuggestionCard extends StatelessWidget {
  const AiSuggestionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding thodi adjust ki hai height maintain rakhne ke liye
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14, 
      ),
      decoration: BoxDecoration(
        color: const Color(0xffFFF2F6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xffFFD7E2),
        ),
      ),
      child: Row(
        children: [
          
          /// Bolt Icon
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Icon(
                Icons.bolt,
                color: Color(0xffFF6B6B),
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          /// Texts (Title & Subtitle)
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, // Ensure karta hai ki extra height na le
              children: [
                Row(
                  children: [
                    Text(
                      "AI Suggestion",
                      style: TextStyle(
                        color: Color(0xffF25F5C),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text("✨", style: TextStyle(fontSize: 14)),
                  ],
                ),
                SizedBox(height: 4),
                // Ye text code me missing tha, maine image se dekh ke add kar diya
                Text(
                  "Order Puja's birthday cake today — bakeries near you are available!",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 8),
          
          /// Act Button
          TextButton(
            onPressed: () {
              // Yahan apna click action daal dena bhai
              print("Act Button Clicked!");
            },
            style: TextButton.styleFrom(
              minimumSize: Size.zero, // Default extra space hatane ke liye
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.white, // Thoda stand-out karega
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              "Act",
              style: TextStyle(
                color: Color(0xff7C3AED),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}