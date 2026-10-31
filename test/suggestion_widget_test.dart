import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/home/widgets/ai_suggestion_card.dart';
import 'package:yaadx/suggestions/suggestion_service.dart';
import 'suggestion_test.dart' show event;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'compact card uses actual name and displays copy/customise actions',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SuggestionPanel(
                uid: 'a',
                event: event('Pritam'),
                service: SuggestionService(),
                currentUid: () => 'a',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Pritam'), findsWidgets);
      expect(find.text('Copy wish'), findsOneWidget);
      expect(find.text('Offline inspiration'), findsOneWidget);
      expect(find.textContaining('Puja'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'customisation fits narrow screen, restores preferences and edits wish',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = SuggestionService();
      await service.saveOptions(
        'a',
        'one',
        SuggestionOptions(language: 'Hindi', interests: 'books'),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SuggestionPanel(
                uid: 'a',
                event: event('Pritam'),
                expanded: true,
                service: service,
                currentUid: () => 'a',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Your wish'),
        'My personal birthday wish',
      );
      await tester.tap(find.text('Use wish'));
      await tester.pumpAndSettle();
      expect(find.text('My personal birthday wish'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
