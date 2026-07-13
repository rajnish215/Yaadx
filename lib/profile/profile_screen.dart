import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),

      appBar: AppBar(
        backgroundColor: const Color(0xffFFF7F6),
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.black,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            const CircleAvatar(
              radius: 55,
              backgroundColor: Color(0xffC8453A),
              child: Icon(
                Icons.person,
                size: 55,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 15),

            const Text(
              "Bhavesh",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            const Text(
              "bhavesh@gmail.com",
              style: TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 35),

            buildTile(Icons.person_outline, "Edit Profile"),
            buildTile(Icons.favorite_outline, "Important Dates"),
            buildTile(Icons.notifications_none, "Notifications"),
            buildTile(Icons.settings_outlined, "Settings"),
            buildTile(Icons.help_outline, "Help & Support"),
            buildTile(Icons.logout, "Logout"),
          ],
        ),
      ),
    );
  }

  Widget buildTile(IconData icon, String title) {
    return Card(
      margin: const EdgeInsets.only(bottom: 15),

      elevation: 2,

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),

      child: ListTile(
        leading: Icon(
          icon,
          color: const Color(0xffC8453A),
        ),

        title: Text(title),

        trailing: const Icon(Icons.arrow_forward_ios, size: 18),
      ),
    );
  }
}