import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../widgets/auth_button.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController();

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final authController =
        context.watch<AuthController>();

    return Scaffold(

      backgroundColor:
          const Color(0xffFFF8F6),

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            const Color(0xffFFF8F6),
      ),

      body: SafeArea(

        child: SingleChildScrollView(

          padding:
              const EdgeInsets.all(24),

          child: Form(

            key: _formKey,

            child: Column(

              children: [

                const SizedBox(height: 20),

                Container(

                  height: 120,
                  width: 120,

                  decoration: BoxDecoration(

                    color: Colors.white,

                    borderRadius:
                        BorderRadius.circular(25),

                    boxShadow: const [

                      BoxShadow(
                        blurRadius: 12,
                        color: Colors.black12,
                      ),

                    ],
                  ),

                  child: const Icon(

                    Icons.lock_reset,

                    size: 60,

                    color:
                        Color(0xffE57373),

                  ),
                ),

                const SizedBox(height: 30),

                const Text(

                  "Forgot Password",

                  style: TextStyle(

                    fontSize: 30,

                    fontWeight:
                        FontWeight.bold,

                    color:
                        Color(0xffE57373),

                  ),
                ),

                const SizedBox(height: 12),

                const Text(

                  "Enter your email address.\nWe'll send you a password reset link.",

                  textAlign: TextAlign.center,

                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 35),

                AuthTextField(

                  controller:
                      emailController,

                  hintText:
                      "Email Address",

                  prefixIcon:
                      Icons.email_outlined,

                  keyboardType:
                      TextInputType.emailAddress,

                  validator: (value) {

                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Enter your email";
                    }

                    if (!value.contains("@")) {
                      return "Invalid email";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 35),

                                AuthButton(
                  text: "Send Reset Link",
                  isLoading: authController.isLoading,

                  onPressed: () async {

                    if (!_formKey.currentState!
                        .validate()) {
                      return;
                    }

                    final result =
                        await authController
                            .resetPassword(
                      emailController.text.trim(),
                    );

                    if (!mounted || !context.mounted) return;

                    if (result == null) {

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Password reset link sent successfully.\nPlease check your email.",
                          ),
                        ),
                      );

                      Navigator.pop(context);

                    } else {

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(result),
                        ),
                      );

                    }
                  },
                ),

                const SizedBox(height: 25),

                TextButton(

                  onPressed: () {

                    Navigator.pop(context);

                  },

                  child: const Text(

                    "Back to Login",

                    style: TextStyle(

                      color: Color(0xffE57373),

                      fontWeight: FontWeight.bold,

                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}