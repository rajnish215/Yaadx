import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_handler.dart';

class AuthController extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  User? get currentUser => _authService.currentUser;

  bool get isEmailVerified =>
      _authService.isEmailVerified;

  Stream<User?> get authStateChanges =>
      _authService.authStateChanges;

  String get userName =>
      _authService.userName;

  String get userEmail =>
      _authService.userEmail;

  String get uid =>
      _authService.uid;

  // ===========================
  // SIGN UP
  // ===========================

  Future<String?> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.signUp(
        name: name,
        email: email,
        password: password,
      );

      await _authService.sendEmailVerification();

      return null;
    } on FirebaseAuthException catch (e) {
     return AuthErrorHandler.getMessage(e);
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================
  // LOGIN
  // ===========================

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      await _authService.login(
        email: email,
        password: password,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return AuthErrorHandler.getMessage(e);
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================
  // LOGOUT
  // ===========================

  Future<void> logout() async {
    await _authService.logout();
  }

  // ===========================
  // RESET PASSWORD
  // ===========================

  Future<String?> resetPassword(
    String email,
  ) async {
    try {
      await _authService.resetPassword(email);

      return null;
    } on FirebaseAuthException catch (e) {
      return AuthErrorHandler.getMessage(e);
    } catch (e) {
      return e.toString();
    }
  }

  // ===========================
  // RELOAD USER
  // ===========================

  Future<void> reloadUser() async {
    await _authService.reloadUser();
    notifyListeners();
    
  }
  // ===========================
// SEND EMAIL VERIFICATION
// ===========================

Future<void> sendEmailVerification() async {
  await _authService.sendEmailVerification();
}
}