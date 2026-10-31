import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../main.dart';
import '../auth/services/startup_session.dart';
import '../auth/services/auth_service.dart';
import '../reminder/notification_service.dart';
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

  String? _error;
  bool _checking = false;

  Future<void> checkLogin() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final user = await refreshStartupSession<User>(
        current: () => FirebaseAuth.instance.currentUser,
        reload: (user) => user.reload(),
        signOut: () async {
          await AuthService().logout();
          try {
            await NotificationService.cancelAll();
          } catch (_) {}
        },
      );
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => user == null
              ? const LoginScreen()
              : user.emailVerified
              ? const MainScreen()
              : const VerifyEmailScreen(),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not check your account. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _checking = false);
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
                borderRadius: BorderRadius.circular(25),

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
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),

            const SizedBox(height: 60),

            if (_error == null)
              const CircularProgressIndicator(color: Color(0xffE57373))
            else ...[
              Text(_error!),
              TextButton(
                onPressed: _checking ? null : checkLogin,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
