import 'package:yaadx/auth/services/auth_service.dart';

class FakeAuthService extends AuthService {
  String name = 'Ankit Kumar';
  String email = 'ankit@example.com';
  bool signedOut = false;
  bool failSave = false;
  int resets = 0;
  String? requestedEmail;
  @override
  String get userName => name;
  @override
  String get userEmail => email;
  @override
  String get uid => 'test-user';
  @override
  bool get isEmailVerified => true;
  @override
  Future<void> updateName(String value) async {
    if (failSave) throw StateError('offline');
    name = value.trim();
  }

  @override
  Future<void> changeEmail(String email, String password) async {
    requestedEmail = email;
  }

  @override
  Future<void> resetPassword(String email) async {
    resets++;
  }

  @override
  Future<void> logout() async {
    signedOut = true;
  }

  @override
  Future<void> reloadUser() async {}
}
