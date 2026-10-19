import 'dart:async';
import 'fake_auth_service.dart';
import 'package:yaadx/auth/controllers/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yaadx/main.dart';
import 'package:yaadx/reminder/reminder_controller.dart';

class StartupController extends ReminderController {
  final pending = Completer<void>();
  int loads = 0;
  bool fail = false;

  @override
  Future<void> loadReminders() async {
    loads++;
    await pending.future;
    if (fail) throw StateError('Storage unavailable');
  }
}

Widget app(ReminderController controller) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: controller),
    ChangeNotifierProvider(
      create: (_) => AuthController(service: FakeAuthService()),
    ),
  ],
  child: const MaterialApp(home: MainScreen()),
);

void main() {
  testWidgets(
    'loads reminders before showing Home without opening another tab',
    (tester) async {
      final controller = StartupController();
      await tester.pumpWidget(app(controller));
      expect(controller.loads, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Quick Actions'), findsNothing);
      controller.pending.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(controller.loads, 1);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('startup load failure can be retried', (tester) async {
    final controller = StartupController()..fail = true;
    controller.pending.complete();
    await tester.pumpWidget(app(controller));
    await tester.pump();
    expect(find.text('Could not load your reminders.'), findsOneWidget);
    controller.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();
    expect(controller.loads, 2);
    expect(find.text('Quick Actions'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
