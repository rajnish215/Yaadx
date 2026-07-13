import 'package:firebase_auth/firebase_auth.dart';

class AuthErrorHandler {
  static String getMessage(
    FirebaseAuthException e,
  ) {
    switch (e.code) {

      case "email-already-in-use":
        return "This email is already registered.";

      case "invalid-email":
        return "Please enter a valid email address.";

      case "invalid-credential":
        return "Incorrect email or password.";

      case "user-not-found":
        return "No account found with this email.";

      case "wrong-password":
        return "Incorrect password.";

      case "weak-password":
        return "Password must contain at least 6 characters.";

      case "too-many-requests":
        return "Too many attempts. Please try again later.";

      case "network-request-failed":
        return "No internet connection.";

      case "user-disabled":
        return "This account has been disabled.";

      case "operation-not-allowed":
        return "This sign in method is not enabled.";

      default:
        return e.message ??
            "Something went wrong.";
    }
  }
}