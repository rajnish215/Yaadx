import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  int _selectedCategoryIndex = 0;
  final List<String> _categories = ["All", "Classes", "Interviews", "Projects", "Personal"];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 1. Top Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text("June 2026", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  Text("Today is Saturday, 27th", style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
              Container(
                height: 45, width: 45,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xffFFE7E5))),
                child: const Icon(Icons.search, color: Color(0xffC8453A)),
              ),
            ],
          ),
          
          const SizedBox(height: 20),

          /// 2. Weather Widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xffE2F0FE), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const Text("🌤️", style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Sitamarhi, Bihar", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xff1E3A8A))),
                    Text("32°C • Mostly Sunny", style: TextStyle(fontSize: 12, color: Color(0xff3B82F6))),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          /// 3. Category Filters
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedCategoryIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategoryIndex = index),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xffC8453A) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isSelected ? const Color(0xffC8453A) : const Color(0xffFFE7E5)),
                    ),
                    child: Text(_categories[index], style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          /// 4. Weekly Calendar (Dates)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildDateCard("Thu", "25", false),
              _buildDateCard("Fri", "26", false),
              _buildDateCard("Sat", "27", true),
              _buildDateCard("Sun", "28", false),
              _buildDateCard("Mon", "29", false),
            ],
          ),

          const SizedBox(height: 30),

          /// 5. Today's Schedule
          const Text("Today's Schedule", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildEventTile("10:00 AM", "Frontend Interview", "InterviewBit practice", const Color(0xffE8EEFF), const Color(0xff5B7FFF), Icons.code),
          const SizedBox(height: 12),
          _buildEventTile("02:30 PM", "Supplier Sync", "Call with vendors", const Color(0xffE8F8F1), const Color(0xff28A86B), Icons.agriculture),

          const SizedBox(height: 35),
          
          /// 6. Add Event Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xffC8453A), Color(0xff8B231C)]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Got a new plan?", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("Add it to your calendar.", style: TextStyle(color: Colors.white70)),
                  ],
                ),
                Container(
                  height: 48, width: 48,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDateCard(String day, String date, bool isActive) {
    return Container(
      height: 75, width: 55,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xffC8453A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isActive ? null : Border.all(color: const Color(0xffFFE7E5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day, style: TextStyle(color: isActive ? Colors.white70 : Colors.grey)),
          Text(date, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildEventTile(String time, String title, String subtitle, Color color, Color iconColor, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xffFFE7E5))),
      child: Row(
        children: [
          Container(height: 50, width: 50, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: iconColor)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(color: Colors.grey))])),
          Text(time, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xffC8453A))),
        ],
      ),
    );
  }
}