import 'package:flutter/material.dart';

import 'widgets/empty_notification.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF7F6),

      appBar: AppBar(
        backgroundColor: const Color(0xffFFF7F6),
        elevation: 0,
        centerTitle: true,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          "Notifications",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: EmptyNotification(),
        ),
      ),
    );
  }
}