import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../login/login_screen.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/widgets/auth_button.dart';
import '../auth/widgets/auth_text_field.dart';
import '../auth/verify_email/verify_email_screen.dart';
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authController =
        context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 20,
          ),

          child: Form(
            key: _formKey,

            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.center,

              children: [

                const SizedBox(height: 20),

                Container(
                  height: 120,
                  width: 120,

                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(20),

                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 10,
                        color: Colors.black12,
                      ),
                    ],
                  ),

                  child: const Icon(
                    Icons.card_giftcard,
                    size: 60,
                    color: Color(0xFFFF6B81),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Create Account",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE85D75),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Let's get you started with YaadX",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                AuthTextField(
                  controller: nameController,
                  hintText: "Full Name",
                  prefixIcon:
                      Icons.person_outline,

                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Enter your name";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AuthTextField(
                  controller: emailController,
                  hintText: "Email",
                  prefixIcon:
                      Icons.email_outlined,

                  keyboardType:
                      TextInputType.emailAddress,

                  validator: (value) {

                    if (value == null ||
                        value.trim().isEmpty) {
                      return "Enter email";
                    }

                    if (!value.contains("@")) {
                      return "Invalid email";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AuthTextField(
                  controller: passwordController,
                  hintText: "Password",
                  prefixIcon:
                      Icons.lock_outline,

                  obscureText: hidePassword,

                  suffixIcon: IconButton(

                    onPressed: () {

                      setState(() {

                        hidePassword =
                            !hidePassword;

                      });

                    },

                    icon: Icon(

                      hidePassword
                          ? Icons.visibility_off
                          : Icons.visibility,

                    ),
                  ),

                  validator: (value) {

                    if (value == null ||
                        value.length < 6) {
                      return "Minimum 6 characters";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                AuthTextField(
                  controller:
                      confirmPasswordController,

                  hintText: "Confirm Password",

                  prefixIcon:
                      Icons.lock_outline,

                  obscureText:
                      hideConfirmPassword,

                  suffixIcon: IconButton(

                    onPressed: () {

                      setState(() {

                        hideConfirmPassword =
                            !hideConfirmPassword;

                      });

                    },

                    icon: Icon(

                      hideConfirmPassword
                          ? Icons.visibility_off
                          : Icons.visibility,

                    ),
                  ),

                  validator: (value) {

                    if (value !=
                        passwordController.text) {

                      return "Password doesn't match";

                    }

                    return null;
                  },
                ),

                const SizedBox(height: 30),

                                AuthButton(
                  text: "Sign Up",
                  isLoading: authController.isLoading,

                  onPressed: () async {

                    if (!_formKey.currentState!
                        .validate()) {
                      return;
                    }

                    final result = await authController.signUp(
  name: nameController.text.trim(),
  email: emailController.text.trim(),
  password: passwordController.text,
);

                    if (!mounted || !context.mounted) return;

                    if (result == null) {

                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Account created successfully.\nPlease verify your email.",
                          ),
                        ),
                      );

                      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const VerifyEmailScreen(),
  ),
);

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

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [

                    const Text(
                      "Already have an account?",
                    ),

                    TextButton(

                      onPressed: () {

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const LoginScreen(),
                          ),
                        );

                      },

                      child: const Text(
                        "Login",
                        style: TextStyle(
                          color: Color(0xFFE85D75),
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}