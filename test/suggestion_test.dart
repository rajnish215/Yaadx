import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/backend/cloud_api.dart';
import 'package:yaadx/suggestions/suggestion_service.dart';
import 'package:yaadx/reminder/reminder_model.dart';

class SuggestionCloud implements CloudGateway {
  int calls = 0;
  bool fail = false;
  Map<String, dynamic>? body;
  @override
  Future<Map<String, dynamic>> request(
    String uid,
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    calls++;
    body = data;
    if (fail) throw const CloudFailure(503, 'ai_not_configured');
    return {
      'wish': 'A wonderful birthday to ${data!['name']}!',
      'source': 'ai',
      'gifts': List.generate(
        3,
        (i) => {'title': 'Gift $i', 'reason': 'A thoughtful idea for you.'},
      ),
    };
  }

  @override
  Future<String> upload(String uid, String path, String kind, String id) =>
      throw UnimplementedError();
  @override
  Future<String> download(String uid, String id) => throw UnimplementedError();
}

ReminderModel event(String name) => ReminderModel(
  id: 'one',
  name: name,
  relation: 'Friend',
  eventType: 'Birthday',
  date: DateTime(2030, 1, 1),
  time: '18:30',
  note: 'Private note',
  phoneNumber: '12345',
  createdAt: DateTime(2026),
);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('edited wishes survive reopening and remain account scoped', () async {
    final service = SuggestionService();
    final o = SuggestionOptions();
    final original = await service.generate('a', event('Ankit'), o);
    await service.saveEdited(
      'a',
      event('Ankit'),
      o,
      original,
      'My personal birthday wish',
    );
    final restored = await SuggestionService().generate('a', event('Ankit'), o);
    expect(restored.wish, 'My personal birthday wish');
    expect(restored.edited, true);
    expect((await service.generate('b', event('Ankit'), o)).edited, false);
    o.variant++;
    expect((await service.generate('a', event('Ankit'), o)).edited, false);
  });
  test('concurrent saves preserve each event and cached edits', () async {
    final one = SuggestionService(), two = SuggestionService();
    final o = SuggestionOptions();
    await Future.wait([
      one.saveOptions('a', 'one', SuggestionOptions(interests: 'books')),
      two.saveOptions('a', 'two', SuggestionOptions(interests: 'music')),
      one.saveEdited(
        'a',
        event('Ankit'),
        o,
        one.offline(event('Ankit'), o),
        'Saved across concurrent writes',
      ),
    ]);
    expect((await one.options('a', 'one')).interests, 'books');
    expect((await two.options('a', 'two')).interests, 'music');
    expect(
      (await one.generate('a', event('Ankit'), o)).wish,
      'Saved across concurrent writes',
    );
  });
  test('malformed variant preferences safely use bounded values', () {
    expect(SuggestionOptions.fromJson({'variant': 'bad'}).variant, 0);
    expect(SuggestionOptions.fromJson({'variant': -5}).variant, 0);
    expect(SuggestionOptions.fromJson({'variant': 99999999}).variant, 1000000);
  });
  test(
    'offline by default; language/tone and event name are reflected',
    () async {
      final cloud = SuggestionCloud(),
          service = SuggestionService(cloud: cloud);
      final result = await service.generate(
        'a',
        event('Ankit'),
        SuggestionOptions(language: 'Hindi'),
      );
      expect(result.ai, false);
      expect(result.wish, contains('Ankit'));
      expect(result.wish, contains('जन्मदिन'));
      expect(result.gifts.length, 3);
      expect(cloud.calls, 0);
      expect(
        service
            .offline(event('Ankit'), SuggestionOptions(tone: 'Short'))
            .wish
            .length,
        lessThan(result.wish.length),
      );
    },
  );
  test(
    'cached AI survives new service, scoped by account and changed event',
    () async {
      final cloud = SuggestionCloud(), o = SuggestionOptions(ai: true);
      await SuggestionService(cloud: cloud).generate('a', event('Ankit'), o);
      final saved = await SuggestionService(
        cloud: cloud,
      ).generate('a', event('Ankit'), o);
      expect(saved.ai, true);
      expect(cloud.calls, 1);
      await SuggestionService(cloud: cloud).generate('b', event('Ankit'), o);
      await SuggestionService(cloud: cloud).generate('a', event('Pritam'), o);
      expect(cloud.calls, 3);
      expect(cloud.body!.keys, isNot(contains('note')));
      expect(cloud.body!.keys, isNot(contains('phoneNumber')));
    },
  );
  test('AI failure returns labelled offline result and can retry', () async {
    final cloud = SuggestionCloud()..fail = true,
        service = SuggestionService(cloud: cloud);
    final live = SuggestionService(cloud: cloud),
        o = SuggestionOptions(ai: true);
    final result = await live.generate('a', event('Ankit'), o);
    expect(result.ai, false);
    expect(result.notice, contains('not set up'));
    cloud.fail = false;
    expect((await live.generate('a', event('Ankit'), o)).ai, true);
    expect((await service.options('b', 'one')).ai, false);
  });
  test(
    'preferences persist per account, interests per event, regeneration varies',
    () async {
      final service = SuggestionService(),
          o = SuggestionOptions(
            language: 'English',
            interests: 'books',
            variant: 1,
            ai: true,
          );
      await service.saveOptions('a', 'one', o);
      final saved = await service.options('a', 'one');
      expect(saved.language, 'English');
      expect(saved.interests, 'books');
      expect((await service.options('a', 'two')).interests, '');
      expect((await service.options('b', 'one')).ai, false);
      expect(
        service.offline(event('Ankit'), o).gifts.first.title,
        contains('book'),
      );
      final first = service.offline(event('Ankit'), SuggestionOptions());
      final next = service.offline(
        event('Ankit'),
        SuggestionOptions(variant: 1),
      );
      expect(next.wish, isNot(first.wish));
    },
  );
}
