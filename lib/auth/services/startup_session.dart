import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';

/// Preserve a cached session only for transient connectivity failures.
Future<T?> refreshStartupSession<T>({
  required T? Function() current,
  required Future<void> Function(T) reload,
  required Future<void> Function() signOut,
  Duration timeout = const Duration(seconds: 8),
}) async {
  final cached = current();
  if (cached == null) return null;
  try {
    await reload(cached).timeout(timeout);
    return current();
  } on TimeoutException {
    return current();
  } on FirebaseAuthException catch (error) {
    if (error.code == 'network-request-failed') return current();
    if (const [
      'user-disabled',
      'user-not-found',
      'user-token-expired',
      'invalid-user-token',
    ].contains(error.code)) {
      await signOut();
      return null;
    }
    rethrow;
  }
}
