import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yaadx/auth/controllers/auth_controller.dart';
import 'package:yaadx/profile/profile_screen.dart';
import 'package:yaadx/profile/edit_profile_screen.dart';
import 'package:yaadx/profile/settings_screen.dart';
import 'package:yaadx/reminder/reminder_controller.dart';
import 'fake_auth_service.dart';

void main() {
  late FakeAuthService service;
  late AuthController auth;
  late ReminderController reminders;
  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    service = FakeAuthService();
    auth = AuthController(service: service);
    reminders = ReminderController(scheduleReminder: (_) async {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('yaadx/reminders'), (
          call,
        ) async {
          if (call.method == 'canScheduleExact') return true;
          if (call.method == 'prepareVoice') return 'content://voice/test.wav';
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (_) async => true,
        );
  });

  Widget app(Widget screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: reminders),
    ],
    child: MaterialApp(home: screen),
  );

  testWidgets('profile shows account identity and saves edited name', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ProfileScreen()));
    expect(find.text('Ankit Kumar'), findsOneWidget);
    expect(find.text('ankit@example.com'), findsOneWidget);
    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'New Name');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(service.name, 'New Name');
    expect(find.text('New Name'), findsOneWidget);
  });

  testWidgets('failed name save stays editable and shows an error', (
    tester,
  ) async {
    service.failSave = true;
    await tester.pumpWidget(app(const EditProfileScreen()));
    await tester.enterText(find.byType(TextFormField), 'Changed');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(service.name, 'Ankit Kumar');
    expect(
      find.text('Could not update your profile. Please try again.'),
      findsOneWidget,
    );
    expect(auth.isLoading, false);
  });

  testWidgets('email change validates password and waits for verification', (
    tester,
  ) async {
    await tester.pumpWidget(app(const ChangeEmailScreen()));
    await tester.tap(find.text('Send verification link'));
    await tester.pump();
    expect(find.text('Enter your current password'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'new@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.text('Send verification link'));
    await tester.pumpAndSettle();
    expect(service.requestedEmail, 'new@example.com');
    expect(service.email, 'ankit@example.com');
    expect(
      find.textContaining('Your email changes only after you verify it'),
      findsOneWidget,
    );
  });

  testWidgets(
    'reset password uses signed-in email and prevents repeated taps',
    (tester) async {
      await tester.pumpWidget(app(const SettingsScreen()));
      await tester.tap(find.text('Reset password'));
      await tester.pumpAndSettle();
      expect(service.resets, 1);
      await tester.tap(find.text('Reset password'));
      expect(service.resets, 1);
    },
  );

  testWidgets('important dates and help routes open', (tester) async {
    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.tap(find.text('Important Dates'));
    await tester.pumpAndSettle();
    expect(find.text('Your Calendar'), findsOneWidget);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Help & Support'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Help & Support'));
    await tester.pumpAndSettle();
    expect(find.text('How do I save an important date?'), findsOneWidget);
  });

  testWidgets(
    'logout cancellation preserves session; confirmation returns to login',
    (tester) async {
      await tester.pumpWidget(app(const ProfileScreen()));
      await tester.scrollUntilVisible(
        find.text('Logout'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(service.signedOut, false);
      await tester.tap(find.text('Logout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(service.signedOut, true);
      expect(find.text('Login'), findsWidgets);
      expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
        false,
      );
    },
  );
}
