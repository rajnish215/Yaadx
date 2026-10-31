import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaadx/auth/services/startup_session.dart';

void main() {
  test('offline startup retains the cached session', () async {
    final result = await refreshStartupSession<String>(
      current: () => 'cached',
      reload: (_) async =>
          throw FirebaseAuthException(code: 'network-request-failed'),
      signOut: () async => fail('Offline users must not be signed out'),
    );
    expect(result, 'cached');
  });
  test('unresponsive reload has a bounded offline fallback', () async {
    final result = await refreshStartupSession<String>(
      current: () => 'cached',
      reload: (_) => Completer<void>().future,
      signOut: () async {},
      timeout: const Duration(milliseconds: 1),
    );
    expect(result, 'cached');
  });
  test(
    'successful reload uses the refreshed session, not stale verification',
    () async {
      String? user = 'unverified';
      final result = await refreshStartupSession<String>(
        current: () => user,
        reload: (_) async {
          user = 'verified';
        },
        signOut: () async {},
      );
      expect(result, 'verified');
    },
  );
  test('disabled accounts cannot use the offline fallback', () async {
    String? user = 'cached';
    final result = await refreshStartupSession<String>(
      current: () => user,
      reload: (_) async => throw FirebaseAuthException(code: 'user-disabled'),
      signOut: () async {
        user = null;
      },
    );
    expect(result, isNull);
    expect(user, isNull);
  });
  test('unknown authentication errors reach the retry UI', () async {
    await expectLater(
      refreshStartupSession<String>(
        current: () => 'cached',
        reload: (_) async =>
            throw FirebaseAuthException(code: 'internal-error'),
        signOut: () async {},
      ),
      throwsA(isA<FirebaseAuthException>()),
    );
  });
  test('account removed during refresh is not restored from cache', () async {
    String? user = 'cached';
    final result = await refreshStartupSession<String>(
      current: () => user,
      reload: (_) async {
        user = null;
        throw FirebaseAuthException(code: 'network-request-failed');
      },
      signOut: () async {},
    );
    expect(result, isNull);
  });
}
