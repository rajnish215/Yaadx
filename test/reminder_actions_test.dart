import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:yaadx/home/widgets/bottom_navbar.dart';
import 'package:yaadx/home/widgets/hero_card.dart';
import 'package:yaadx/reminder/add_reminder_screen.dart';
import 'package:yaadx/reminder/reminder_controller.dart';
import 'package:yaadx/reminder/reminder_model.dart';

class EditingController extends ReminderController {
  ReminderModel event = ReminderModel(
    id: 'same-id',
    name: 'Riya',
    relation: 'Friend',
    eventType: 'Birthday',
    date: DateTime(2030, 12, 5),
    time: '18:30',
    note: 'Gift',
    voiceNotePath: '/saved.m4a',
    voiceNoteCompleted: true,
    notificationEnabled: false,
    memoryCaption: 'Happy Birthday!',
    createdAt: DateTime(2026),
    repeatYearly: true,
  );
  int additions = 0;
  int edits = 0;
  @override
  List<ReminderModel> get reminders => [event];
  @override
  List<ReminderModel> get upcomingReminders => [event];
  @override
  List<ReminderModel> get todayReminders => [];
  @override
  Future<void> addReminder(ReminderModel r) async {
    additions++;
  }

  @override
  Future<void> updateReminder(ReminderModel r) async {
    event = r;
    edits++;
    notifyListeners();
  }
}

void main() {
  Widget app(Widget child, EditingController controller) =>
      ChangeNotifierProvider<ReminderController>.value(
        value: controller,
        child: MaterialApp(home: Scaffold(body: child)),
      );
  testWidgets('bottom add opens form', (tester) async {
    await tester.pumpWidget(
      app(BottomNavbar(currentIndex: 0, onTap: (_) {}), EditingController()),
    );
    await tester.tap(find.byTooltip('Add reminder'));
    await tester.pumpAndSettle();
    expect(find.text('Add Reminder'), findsOneWidget);
  });
  testWidgets('Celebrate Now opens saved-event actions', (tester) async {
    await tester.pumpWidget(app(const HeroCard(), EditingController()));
    await tester.tap(find.text('Celebrate Now'));
    await tester.pumpAndSettle();
    expect(find.text('Share wish and photos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'editing updates same event and preserves voice, disabled alerts and creation date',
    (tester) async {
      final controller = EditingController();
      await tester.pumpWidget(
        app(AddReminderScreen(reminder: controller.event), controller),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Riya'),
        'Riya Updated',
      );
      await tester.scrollUntilVisible(
        find.text('Save Reminder'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save Reminder'));
      await tester.pumpAndSettle();
      expect(controller.edits, 1);
      expect(controller.additions, 0);
      expect(controller.event.id, 'same-id');
      expect(controller.event.name, 'Riya Updated');
      expect(controller.event.voiceNotePath, '/saved.m4a');
      expect(controller.event.notificationEnabled, false);
      expect(controller.event.createdAt, DateTime(2026));
      expect(controller.event.time, '18:30');
    },
  );
}
