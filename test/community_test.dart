import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/backend/cloud_api.dart';
import 'package:yaadx/backend/community_screen.dart';
import 'package:yaadx/reminder/reminder_service.dart';

class InboxCloud implements CloudGateway {
  Completer<Map<String, dynamic>>? pending;
  final calls = <Map<String, dynamic>>[];
  bool failSend = false;
  List<Map<String, dynamic>> tickets = [];
  @override
  Future<Map<String, dynamic>> request(
    String uid,
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    calls.add({'uid': uid, 'method': method, 'path': path, 'data': data});
    if (path == '/v1/community' && pending != null) return pending!.future;
    if (method == 'POST') {
      if (failSend) throw const CloudFailure(503, 'unavailable');
      return {'ok': true};
    }
    return {
      'announcements': [
        {
          'id': 'notice',
          'title': 'Welcome update',
          'body': 'Your admin announcement',
          'is_read': false,
        },
      ],
      'tickets': tickets,
      'subscription': {'plan': 'free'},
      'settings': {},
    };
  }

  @override
  Future<String> upload(
    String uid,
    String path,
    String kind,
    String id,
  ) async => throw UnimplementedError();
  @override
  Future<String> download(String uid, String id) async =>
      throw UnimplementedError();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReminderService().useAccount('inbox-alice');
  });
  tearDown(() {
    ReminderService().cloud = null;
  });
  testWidgets('inbox marks announcement read through authenticated account', (
    tester,
  ) async {
    final cloud = InboxCloud();
    ReminderService().cloud = cloud;
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Welcome update'), findsOneWidget);
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();
    expect(
      cloud.calls.any(
        (r) =>
            r['uid'] == 'inbox-alice' &&
            r['path'] == '/v1/community/announcements/notice/read',
      ),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('late inbox response is discarded after account changes', (
    tester,
  ) async {
    final cloud = InboxCloud()..pending = Completer<Map<String, dynamic>>();
    ReminderService().cloud = cloud;
    await tester.pumpWidget(const MaterialApp(home: CommunityScreen()));
    await tester.pump();
    await ReminderService().useAccount('inbox-bob');
    cloud.pending!.complete({
      'announcements': [
        {'title': 'Alice private notice', 'body': 'private'},
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('Alice private notice'), findsNothing);
    expect(find.text('Account changed. Reopen your inbox.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'failed support request preserves input and retries the same operation',
    (tester) async {
      final cloud = InboxCloud()..failSend = true;
      ReminderService().cloud = cloud;
      await tester.pumpWidget(
        const MaterialApp(home: CommunityScreen(initialTab: 1)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Reminder help');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'My reminder needs help.',
      );
      await tester.ensureVisible(find.text('Send request'));
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      expect(find.text('My reminder needs help.'), findsOneWidget);
      cloud.failSend = false;
      await tester.tap(find.text('Send request'));
      await tester.pumpAndSettle();
      final posts = cloud.calls.where((r) => r['method'] == 'POST').toList();
      expect(posts, hasLength(2));
      expect(posts[0]['data']['id'], posts[1]['data']['id']);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('support follow-up preserves text and operation on retry', (
    tester,
  ) async {
    final cloud = InboxCloud()
      ..failSend = true
      ..tickets = [
        {
          'id': 'ticket-1',
          'subject': 'Help request',
          'message': 'Original request',
          'status': 'open',
          'reply': '',
          'messages': [
            {'author': 'admin', 'body': 'Please tell us more.'},
          ],
        },
      ];
    ReminderService().cloud = cloud;
    await tester.pumpWidget(
      const MaterialApp(home: CommunityScreen(initialTab: 1)),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add reply'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add reply'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'Here are the details.',
    );
    await tester.tap(find.text('Send reply'));
    await tester.pumpAndSettle();
    expect(find.text('Here are the details.'), findsOneWidget);
    cloud.failSend = false;
    await tester.tap(find.text('Send reply'));
    await tester.pumpAndSettle();
    final posts = cloud.calls
        .where((r) => r['path'] == '/v1/community/tickets/ticket-1/messages')
        .toList();
    expect(posts, hasLength(2));
    expect(posts[0]['uid'], 'inbox-alice');
    expect(posts[0]['data']['id'], posts[1]['data']['id']);
    expect(find.byType(AlertDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
