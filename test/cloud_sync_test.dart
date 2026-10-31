import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yaadx/backend/cloud_api.dart';
import 'package:yaadx/reminder/reminder_model.dart';
import 'package:yaadx/reminder/reminder_service.dart';

class FakeCloud implements CloudGateway {
  final records = <String, Map<String, Map<String, dynamic>>>{};
  final operations = <String, Map<String, dynamic>>{};
  bool offline = false, loseResponse = false;
  @override
  Future<Map<String, dynamic>> request(
    String uid,
    String method,
    String path, [
    Map<String, dynamic>? data,
  ]) async {
    if (offline) throw const CloudFailure(503, 'offline');
    if (path == '/v1/profile') return {'uid': uid};
    if (path == '/v1/preferences') {
      return {'alertsEnabled': data?['alertsEnabled'] ?? true, 'version': 1};
    }
    final account = records.putIfAbsent(uid, () => {});
    if (method == 'GET') return {'reminders': account.values.toList()};
    final key = '$uid:${data!['operationId']}';
    if (operations.containsKey(key)) return operations[key]!;
    final id = path.split('/').last;
    if ((account[id]?['version'] ?? 0) != data['baseVersion']) {
      throw const CloudFailure(409, 'version_conflict');
    }
    final result = {
      'id': id,
      'version': (data['baseVersion'] as int) + 1,
      'data': data['data'] ?? account[id]?['data'],
      'deleted': data['data'] == null,
    };
    account[id] = result;
    operations[key] = result;
    if (loseResponse) {
      loseResponse = false;
      throw const CloudFailure(503, 'timeout');
    }
    return result;
  }

  @override
  Future<String> upload(
    String uid,
    String path,
    String kind,
    String id,
  ) async => throw const CloudFailure(503, 'media_storage_not_configured');
  @override
  Future<String> download(String uid, String id) async =>
      throw const CloudFailure(503, 'media_storage_not_configured');
}

ReminderModel reminder(String id) => ReminderModel(
  id: id,
  name: 'Ankit',
  relation: 'Friend',
  eventType: 'Birthday',
  date: DateTime(2030, 1, 2),
  time: '6:30 PM',
  note: '',
  createdAt: DateTime(2026),
  voiceAlert: true,
  repeatYearly: true,
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = ReminderService();
  late FakeCloud cloud;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    cloud = FakeCloud();
    service.cloud = cloud;
    await service.useAccount('alice');
  });
  tearDown(() async {
    service.cloud = null;
    await service.useAccount(null);
  });
  test(
    'offline edits survive restart and retry never duplicates a lost response',
    () async {
      cloud.offline = true;
      await service.addReminder(reminder('one'));
      await service.sync();
      expect((await service.getReminders()).single.name, 'Ankit');
      await service.useAccount('alice');
      cloud.offline = false;
      cloud.loseResponse = true;
      await service.sync();
      await service.sync();
      expect(cloud.records['alice']!.length, 1);
      expect(cloud.records['alice']!['one']!['version'], 1);
      expect(cloud.records['alice']!['one']!['data']['time'], '18:30');
      expect(cloud.records['alice']!['one']!['data']['voiceAlert'], true);
    },
  );
  test('accounts isolated and delete tombstone survives restart', () async {
    await service.addReminder(reminder('one'));
    await service.sync();
    await service.useAccount('bob');
    await service.sync();
    expect(await service.getReminders(), isEmpty);
    await service.useAccount('alice');
    await service.deleteReminder('one');
    await service.useAccount('alice');
    await service.sync();
    expect(await service.getReminders(), isEmpty);
    expect(cloud.records['alice']!['one']!['deleted'], true);
  });
  test(
    'legacy backup retained, remote conflict never overwrites pending local data',
    () async {
      await service.addReminder(reminder('one'));
      await service.sync();
      final remote = cloud.records['alice']!['one']!;
      remote['version'] = 2;
      remote['data'] = {...remote['data'] as Map, 'name': 'Remote'};
      await service.updateReminder(reminder('one').copyWith(name: 'Local'));
      await service.sync();
      expect(service.hasConflicts, true);
      expect((await service.getReminders()).single.name, 'Local');
      await service.resolveConflict('one', keepLocal: true);
      await service.sync();
      expect(cloud.records['alice']!['one']!['data']['name'], 'Local');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.contains('conflict_backup')), true);
    },
  );
  test(
    'media setup failure preserves local event and syncs other events',
    () async {
      await service.addReminder(
        reminder('media').copyWith(memoryPhotoPaths: ['/local/photo.jpg']),
      );
      await service.addReminder(reminder('plain'));
      await service.sync();
      expect((await service.getReminders()).length, 2);
      expect(cloud.records['alice']!.containsKey('plain'), true);
      expect(cloud.records['alice']!.containsKey('media'), false);
      expect(service.syncStatus.value, contains('cloud storage setup'));
    },
  );
  test('original account snapshot retained during initial migration', () async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode([
      {
        'id': 'legacy',
        'name': 'Old',
        'relation': 'Friend',
        'eventType': 'Birthday',
        'date': '2030-01-01',
        'time': '18:30',
        'createdAt': '2026-01-01',
      },
    ]);
    await prefs.setString('yaadx_reminders_newuser', raw);
    await service.useAccount('newuser');
    await service.sync();
    expect(prefs.getString('yaadx_reminders_newuser'), raw);
    expect(prefs.getString('yaadx_reminders_newuser_pre_cloud_backup'), raw);
    expect(cloud.records['newuser']!['legacy'], isNotNull);
  });
  test(
    'deleting an unsent create does not leave an impossible remote mutation',
    () async {
      cloud.offline = true;
      await service.addReminder(reminder('unsent'));
      await service.deleteReminder('unsent');
      cloud.offline = false;
      await service.sync();
      expect(cloud.records['alice'], isEmpty);
      expect(service.syncStatus.value, 'Cloud sync complete');
    },
  );
}
