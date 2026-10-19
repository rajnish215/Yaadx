import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';
import '../services/auth_error_handler.dart';

class AuthController extends ChangeNotifier {
  AuthController({AuthService? service})
    : _authService = service ?? AuthService();
  final AuthService _authService;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  User? get currentUser => _authService.currentUser;

  bool get isEmailVerified => _authService.isEmailVerified;

  Stream<User?> get authStateChanges => _authService.authStateChanges;

  String get userName => _authService.userName;

  String get userEmail => _authService.userEmail;

  String get uid => _authService.uid;

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

      await _authService.signUp(name: name, email: email, password: password);

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

      await _authService.login(email: email, password: password);

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
    notifyListeners();
  }

  Future<String?> updateProfileName(String name) async {
    if (name.trim().isEmpty) return 'Please enter your name.';
    return _profileAction(() => _authService.updateName(name));
  }

  Future<String?> changeEmail(String email, String password) =>
      _profileAction(() => _authService.changeEmail(email, password));

  Future<String?> _profileAction(Future<void> Function() action) async {
    if (_isLoading) return 'Please wait for the current request.';
    _isLoading = true;
    notifyListeners();
    try {
      await action();
      return null;
    } on FirebaseAuthException catch (error) {
      return AuthErrorHandler.getMessage(error);
    } catch (_) {
      return 'Could not update your profile. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===========================
  // RESET PASSWORD
  // ===========================

  Future<String?> resetPassword(String email) async {
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
