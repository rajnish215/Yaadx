import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yaadx/backend/cloud_api.dart';
import 'package:yaadx/reminder/reminder_service.dart';
import 'package:yaadx/reminder/reminder_model.dart';
import 'package:yaadx/reminder/notification_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Firebase emulator → API → Neon: migration, restart, isolation, edit/delete',
    (tester) async {
      final app = await Firebase.initializeApp(
        name: 'yaadx-qa',
        options: const FirebaseOptions(
          apiKey: 'demo-api-key',
          appId: '1:1234567890:android:1234567890',
          messagingSenderId: '1234567890',
          projectId: 'demo-yaadx',
        ),
      );
      final auth = FirebaseAuth.instanceFor(app: app);
      const testHost = String.fromEnvironment(
        'YAADX_TEST_HOST',
        defaultValue: '10.0.2.2',
      );
      await auth.useAuthEmulator(testHost, 9099, automaticHostMapping: false);
      final service = ReminderService();
      service.cloud = CloudApi(
        baseUrl: 'http://$testHost:8081',
        currentUid: () => auth.currentUser?.uid,
        token: (force) async => auth.currentUser?.getIdToken(force),
      );
      final suffix = DateTime.now().microsecondsSinceEpoch.toString();
      final email = 'qa-$suffix@example.test';
      const password = 'OnlyLocalEmulator123!';
      final first = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final alice = first.user!.uid;
      await service.useAccount(alice);
      final r = ReminderModel(
        id: 'qa-$suffix',
        name: 'QA Ankit',
        relation: 'Friend',
        eventType: 'Birthday',
        date: DateTime.now().add(const Duration(days: 12)),
        time: '6:30 PM',
        note: 'Integration QA only',
        createdAt: DateTime.now(),
        repeatYearly: true,
        advanceDays: 10,
        voiceAlert: false,
      );
      try {
        await service.addReminder(r);
        await service.sync();
        expect(service.syncStatus.value, 'Cloud sync complete');
        await service.useAccount(alice);
        await service.sync();
        expect((await service.getReminders()).single.time, '18:30');
        await auth.signOut();
        final second = await auth.createUserWithEmailAndPassword(
          email: 'qa-b-$suffix@example.test',
          password: password,
        );
        await service.useAccount(second.user!.uid);
        await service.sync();
        expect(await service.getReminders(), isEmpty);
        await auth.currentUser!.delete();
        await auth.signInWithEmailAndPassword(email: email, password: password);
        await service.useAccount(alice);
        await service.updateReminder(r.copyWith(name: 'Edited QA'));
        await service.sync();
        await service.useAccount(alice);
        await service.sync();
        expect((await service.getReminders()).single.name, 'Edited QA');
        await NotificationService.initialize();
        await NotificationService.scheduleReminder(r);
        await NotificationService.cancelReminder(r.id);
        await service.deleteReminder(r.id);
        await service.sync();
        expect(await service.getReminders(), isEmpty);
        expect(service.syncStatus.value, 'Cloud sync complete');
      } finally {
        try {
          if (auth.currentUser != null) await auth.currentUser!.delete();
        } catch (_) {
          // Preserve the original test failure if cleanup loses connectivity.
          debugPrint(
            'QA auth cleanup unavailable; disposable emulator user retained.',
          );
        }
        service.cloud = null;
        await service.useAccount(null);
        await app.delete();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
