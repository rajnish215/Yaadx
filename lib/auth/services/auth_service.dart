import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ===========================
  // Current User
  // ===========================

  User? get currentUser => _auth.currentUser;

  // ===========================
  // Auth State Changes
  // ===========================

  Stream<User?> get authStateChanges =>
      _auth.authStateChanges();

  // ===========================
  // SIGN UP
  // ===========================

  Future<UserCredential> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final credential =
        await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await credential.user!.updateDisplayName(
      name.trim(),
    );

    await credential.user!.reload();

    return credential;
  }

  // ===========================
  // LOGIN
  // ===========================

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // ===========================
  // LOGOUT
  // ===========================

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ===========================
  // RESET PASSWORD
  // ===========================

  Future<void> resetPassword(
    String email,
  ) async {
    await _auth.sendPasswordResetEmail(
      email: email.trim(),
    );
  }

  // ===========================
  // SEND EMAIL VERIFICATION
  // ===========================

  Future<void> sendEmailVerification() async {
    if (_auth.currentUser != null &&
        !_auth.currentUser!.emailVerified) {
      await _auth.currentUser!
          .sendEmailVerification();
    }
  }

  // ===========================
  // RELOAD USER
  // ===========================

  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // ===========================
  // EMAIL VERIFIED
  // ===========================

  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ??
        false;
  }

  // ===========================
  // GET USER NAME
  // ===========================

  String get userName {
    return _auth.currentUser?.displayName ?? "";
  }

  // ===========================
  // GET USER EMAIL
  // ===========================

  String get userEmail {
    return _auth.currentUser?.email ?? "";
  }

  // ===========================
  // GET USER UID
  // ===========================

  String get uid {
    return _auth.currentUser?.uid ?? "";
  }
}