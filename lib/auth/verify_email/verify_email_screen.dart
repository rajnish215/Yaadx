import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../../main.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() =>
      _VerifyEmailScreenState();
}

class _VerifyEmailScreenState
    extends State<VerifyEmailScreen> {

  Timer? _timer;

  bool checking = false;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        checkVerification();
      },
    );
  }

  Future<void> checkVerification() async {

    await context
        .read<AuthController>()
        .reloadUser();

    if (!mounted || !context.mounted) return;

    final auth =
        context.read<AuthController>();

    if (auth.isEmailVerified) {

      _timer?.cancel();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              const MainScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final authController =
        context.watch<AuthController>();

    return Scaffold(

      backgroundColor:
          const Color(0xffFFF8F6),

      body: SafeArea(

        child: Padding(

          padding:
              const EdgeInsets.all(24),

          child: Column(

            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              Container(

                height: 130,
                width: 130,

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(30),

                  boxShadow: [

                    BoxShadow(
                      color:
                          Colors.pink.shade100,
                      blurRadius: 20,
                    ),
                  ],
                ),

                child: const Icon(

                  Icons.mark_email_read,

                  size: 70,

                  color:
                      Color(0xffE57373),
                ),
              ),

              const SizedBox(height: 35),

              const Text(

                "Verify Your Email",

                textAlign:
                    TextAlign.center,

                style: TextStyle(

                  fontSize: 30,

                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              Text(

                authController.userEmail,

                textAlign:
                    TextAlign.center,

                style: const TextStyle(

                  fontSize: 17,

                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 15),

              const Text(

                "We've sent a verification link to your email.\nPlease verify your account before continuing.",

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 20),

              const Text(

                "Checking verification status automatically...",

                textAlign:
                    TextAlign.center,

                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 40),

                            SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: checking
                      ? null
                      : () async {

                          setState(() {
                            checking = true;
                          });

                          await checkVerification();

                          if (!mounted || !context.mounted) return;

                          setState(() {
                            checking = false;
                          });

                          if (!authController
                              .isEmailVerified) {

                            ScaffoldMessenger.of(context)
                                .showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Email not verified yet.\nPlease verify and try again.",
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        const Color(0xffE57373),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: checking
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child:
                              CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          "I've Verified",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton(
                  onPressed: () async {

                    await authController
                        .sendEmailVerification();

                    if (!mounted || !context.mounted) return;

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Verification email sent successfully.",
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(0xffE57373),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    "Resend Email",
                    style: TextStyle(
                      color: Color(0xffE57373),
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () async {

                  await authController.logout();

                  if (!mounted || !context.mounted) return;

                  Navigator.pop(context);

                },
                child: const Text(
                  "Back to Login",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}