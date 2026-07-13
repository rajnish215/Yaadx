import '../main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../signup/signup_screen.dart';
import '../auth/controllers/auth_controller.dart';
import '../auth/widgets/auth_button.dart';
import '../auth/widgets/auth_text_field.dart';
import '../auth/forgot_password/forgot_password_screen.dart';
import '../auth/verify_email/verify_email_screen.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool hidePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
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

        child: SingleChildScrollView(

          padding:
              const EdgeInsets.all(25),

          child: Form(

            key: _formKey,

            child: Column(

              children: [

                const SizedBox(height: 50),

                const Text(

                  "Welcome Back!",

                  style: TextStyle(

                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold,

                    color:
                        Color(0xffE57373),

                  ),
                ),

                const SizedBox(height: 8),

                const Text(

                  "Login to your YaadX account",

                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 30),

                Container(

                  height: 180,
                  width: 180,

                  decoration: BoxDecoration(

                    color:
                        Colors.pink.shade50,

                    borderRadius:
                        BorderRadius.circular(
                      25,
                    ),
                  ),

                  child: const Icon(

                    Icons.calendar_month,

                    size: 90,

                    color:
                        Color(0xffE57373),
                  ),
                ),

                const SizedBox(height: 30),

                AuthTextField(

                  controller:
                      emailController,

                  hintText:
                      "Email Address",

                  prefixIcon:
                      Icons.email,

                  keyboardType:
                      TextInputType
                          .emailAddress,

                  validator: (value) {

                    if (value == null ||
                        value.isEmpty) {
                      return "Enter email";
                    }

                    if (!value
                        .contains("@")) {
                      return "Invalid Email";
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 18),

                AuthTextField(

                  controller:
                      passwordController,

                  hintText:
                      "Password",

                  prefixIcon:
                      Icons.lock,

                  obscureText:
                      hidePassword,

                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            hidePassword = !hidePassword;
                          });
                        },
                      

                    icon: Icon(

                      hidePassword

                          ? Icons
                              .visibility_off

                          : Icons
                              .visibility,

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

                const SizedBox(height: 10),

                Align(

                  alignment:
                      Alignment.centerRight,

                  child: TextButton(

                    onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const ForgotPasswordScreen(),
    ),
  );
},

                    child: const Text(

                      "Forgot Password?",

                      style: TextStyle(
                        color:
                            Color(0xffE57373),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                                AuthButton(
                  text: "Login",
                  isLoading: authController.isLoading,

                  onPressed: () async {

                    if (!_formKey.currentState!
                        .validate()) {
                      return;
                    }

                    final result =
                        await authController.login(
                      email:
                          emailController.text.trim(),
                      password:
                          passwordController.text,
                    );

                    if (!mounted) return;

                    if (result == null) {

                      await authController
                          .reloadUser();

                      if (!mounted) return;

                      if (authController.isEmailVerified) {

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const MainScreen(),
    ),
  );

} else {

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const VerifyEmailScreen(),
    ),
  );

}

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

                const Text(
                  "or continue with",
                ),

                const SizedBox(height: 20),

                Row(
                  children: [

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {

                          // Google Login
                          // Next Update

                        },

                        icon: const Icon(
                          Icons.g_mobiledata,
                        ),

                        label: const Text(
                          "Google",
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {

                          // Apple Login

                        },

                        icon: const Icon(
                          Icons.apple,
                        ),

                        label: const Text(
                          "Apple",
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [

                    const Text(
                      "Don't have an account?",
                    ),

                    TextButton(

                      onPressed: () {

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const SignupScreen(),
                          ),
                        );

                      },

                      child: const Text(

                        "Sign Up",

                        style: TextStyle(
                          color:
                              Color(0xffE57373),
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