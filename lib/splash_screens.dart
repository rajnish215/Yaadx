import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screens.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();

    Timer(
      const Duration(seconds: 3),
      () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffFFF5F5),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.shade100,
                    blurRadius: 15,
                  )
                ],
              ),
              child: const Icon(
                Icons.notifications_active,
                size: 50,
                color: Colors.pink,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "YaadX",
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.bold,
                color: Color(0xffE57373),
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Never Miss A Special Moment",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 60),

            const CircularProgressIndicator(
              color: Color(0xffE57373),
            ),
          ],
        ),
      ),
    );
  }
}