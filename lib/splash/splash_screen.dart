import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../login/login_screen.dart';
import '../verify_email/verify_email_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    await user?.reload();

    if (user == null) {

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    ),
  );

} else {

  if (user.emailVerified) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const MainScreen(),
      ),
    );

  } else {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const VerifyEmailScreen(),
      ),
    );

  }

}
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
                borderRadius:
                    BorderRadius.circular(25),

                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.shade100,
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
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