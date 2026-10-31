import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/cloud_api.dart';
import 'reminder_model.dart';
import 'reminder_validation.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();
  CloudGateway? cloud;
  final ValueNotifier<String> syncStatus = ValueNotifier(
    'Saved on this device',
  );
  String? _uid;
  String? get accountId => _uid;
  String _storageKey = 'yaadx_reminders';
  int _epoch = 0;
  Future<void>? _tail;
  List<ReminderModel> _database = [];
  Map<String, dynamic> _versions = {},
      _pending = {},
      _media = {},
      _conflicts = {};
  bool _isLoaded = false;
  bool get cloudEnabled => cloud != null;
  bool get hasConflicts => _conflicts.isNotEmpty;
  List<Map<String, dynamic>> get conflicts => _conflicts.entries
      .map((e) => {'id': e.key, ...Map<String, dynamic>.from(e.value as Map)})
      .toList();
  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail == null
        ? Future<T>.sync(action)
        : _tail!.then((_) => action());
    final tail = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _tail = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tail, tail)) _tail = null;
      }),
    );
    return next;
  }

  Future<void> useAccount(String? uid, {bool migrateLegacy = false}) {
    _epoch++;
    return _serial(() async {
      final prefs = await SharedPreferences.getInstance();
      final nextKey = uid == null ? 'yaadx_signed_out' : 'yaadx_reminders_$uid';
      if (migrateLegacy && uid != null) {
        final legacy = prefs.getString('yaadx_reminders');
        final owner = prefs.getString('yaadx_legacy_owner');
        if (legacy != null && (owner == null || owner == uid)) {
          if (owner == null &&
              !await prefs.setString('yaadx_legacy_owner', uid)) {
            throw StateError('Could not assign saved reminders.');
          }
          if (!prefs.containsKey(nextKey) &&
              !await prefs.setString(nextKey, legacy)) {
            throw StateError('Could not migrate saved reminders.');
          }
          // Retain the original; removal requires explicit user approval.
        }
      }
      _uid = uid;
      _storageKey = nextKey;
      _database = [];
      _versions = {};
      _pending = {};
      _media = {};
      _conflicts = {};
      _isLoaded = false;
      _preferenceVersion = null;
      _pendingAlert = null;
      if (!prefs.containsKey(alertsKey) &&
          prefs.containsKey('yaadx_alerts_enabled') &&
          (prefs.getString('yaadx_legacy_owner') == null ||
              prefs.getString('yaadx_legacy_owner') == uid)) {
        await prefs.setBool(alertsKey, prefs.getBool('yaadx_alerts_enabled')!);
      }
      syncStatus.value = cloud == null
          ? 'Saved on this device'
          : 'Cloud sync pending';
    });
  }

  Future<void> _loadFromStorage() async {
    if (_isLoaded) return;
    final prefs = await SharedPreferences.getInstance();
    final envelope = prefs.getString('${_storageKey}_cloud_v1');
    if (envelope != null) {
      final state = jsonDecode(envelope) as Map;
      _database = (state['data'] as List)
          .map((v) => _fromJson(Map<String, dynamic>.from(v as Map)))
          .toList();
      _versions = Map<String, dynamic>.from(state['versions'] as Map);
      _pending = Map<String, dynamic>.from(state['pending'] as Map);
      _media = Map<String, dynamic>.from(state['media'] as Map);
      _conflicts = Map<String, dynamic>.from(state['conflicts'] as Map);
      _preferenceVersion = state['preferenceVersion'] as int?;
      _pendingAlert = state['pendingAlert'] as bool?;
    } else {
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        if (!prefs.containsKey('${_storageKey}_pre_cloud_backup') &&
            !await prefs.setString('${_storageKey}_pre_cloud_backup', raw)) {
          throw StateError('Could not back up local reminders.');
        }
        _database = (jsonDecode(raw) as List)
            .map((v) => _fromJson(Map<String, dynamic>.from(v as Map)))
            .toList();
      }
      _pendingAlert = prefs.getBool(alertsKey);
      for (final r in _database) {
        _queue(r.id, r);
      }
    }
    _isLoaded = true;
  }

  void _queue(String id, ReminderModel? reminder) {
    if (reminder == null &&
        !_versions.containsKey(id) &&
        ((_pending[id] as Map?)?['body'] == null)) {
      // An unsent local create can be removed without a remote delete.
      _pending.remove(id);
      _conflicts.remove(id);
      return;
    }
    _pending[id] = {
      'operationId': newOperationId(),
      'baseVersion': _versions[id] ?? 0,
      'local': reminder == null ? null : _toJson(reminder),
    };
    _conflicts.remove(id);
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    // One atomic value holds local data, versions and the durable mutation outbox.
    if (!await prefs.setString(
      '${_storageKey}_cloud_v1',
      jsonEncode({
        'data': _database.map(_toJson).toList(),
        'versions': _versions,
        'pending': _pending,
        'media': _media,
        'conflicts': _conflicts,
        'preferenceVersion': _preferenceVersion,
        'pendingAlert': _pendingAlert,
      }),
    )) {
      _isLoaded = false;
      throw StateError('Could not save reminders.');
    }
    // Original legacy/account keys and pre-cloud backup remain untouched.
  }

  Future<List<ReminderModel>> getReminders() => _serial(() async {
    await _loadFromStorage();
    return List.of(_database);
  });
  Future<ReminderModel?> getReminderById(String id) => _serial(() async {
    await _loadFromStorage();
    for (final r in _database) {
      if (r.id == id) return r;
    }
    return null;
  });
  Future<void> _change(String id, ReminderModel? r) => _serial(() async {
    if (r != null) ReminderValidation.check(r);
    await _loadFromStorage();
    _database.removeWhere((v) => v.id == id);
    if (r != null) _database.add(r);
    _queue(id, r);
    await _saveToStorage();
  });
  Future<void> addReminder(ReminderModel r) => _change(r.id, r);
  Future<void> updateReminder(ReminderModel r) => _change(r.id, r);
  Future<void> deleteReminder(String id) => _change(id, null);
  Future<void> clearAll() => _serial(() async {
    await _loadFromStorage();
    for (final r in _database) {
      _queue(r.id, null);
    }
    _database = [];
    await _saveToStorage();
  });
  // Convert reminder to JSON.
  Map<String, dynamic> _toJson(ReminderModel reminder) {
    return {
      'id': reminder.id,
      'name': reminder.name,
      'relation': reminder.relation,
      'phoneNumber': reminder.phoneNumber,
      'eventType': reminder.eventType,
      'date': reminder.date.toIso8601String(),
      'time': reminder.time,
      'note': reminder.note,

      // Photo memory fields
      'memoryPhotoPaths': reminder.memoryPhotoPaths,
      'memoryCaption': reminder.memoryCaption,

      // Voice note
      'voiceNotePath': reminder.voiceNotePath,

      // Event preparation checklist
      'voiceNoteCompleted': reminder.voiceNoteCompleted,
      'messageSent': reminder.messageSent,

      // Settings
      'repeatYearly': reminder.repeatYearly,
      'advanceDays': reminder.advanceDays,
      'voiceAlert': reminder.voiceAlert,
      'notificationEnabled': reminder.notificationEnabled,
      'isCompleted': reminder.isCompleted,

      // Metadata
      'createdAt': reminder.createdAt.toIso8601String(),
    };
  }

  // Convert JSON back to a reminder.
  // Defaults maintain compatibility with older saved reminders.
  ReminderModel _fromJson(Map<String, dynamic> json) {
    final savedPhotoPaths = json['memoryPhotoPaths'];

    return ReminderModel(
      id: json['id'] as String,
      name: json['name'] as String,
      relation: json['relation'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      eventType: json['eventType'] as String,
      date: DateTime.parse(json['date'] as String),
      time: json['time'] as String,
      note: json['note'] as String? ?? '',

      // Photo memory fields
      memoryPhotoPaths: savedPhotoPaths is List
          ? savedPhotoPaths.whereType<String>().toList()
          : const [],
      memoryCaption: json['memoryCaption'] as String? ?? '',

      // Voice note
      voiceNotePath: json['voiceNotePath'] as String?,

      // Event preparation checklist
      voiceNoteCompleted: json['voiceNoteCompleted'] as bool? ?? false,
      messageSent: json['messageSent'] as bool? ?? false,

      // Settings
      repeatYearly: json['repeatYearly'] as bool? ?? false,
      advanceDays: (json['advanceDays'] as int? ?? 10).clamp(0, 10),
      voiceAlert: json['voiceAlert'] as bool? ?? false,
      notificationEnabled: json['notificationEnabled'] as bool? ?? true,
      isCompleted: json['isCompleted'] as bool? ?? false,

      // Metadata
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Future<Map<String, dynamic>> _wire(ReminderModel r, String uid) async {
    final photos = <String>[];
    Future<String> mediaId(String path, String kind) async {
      final known = Map<String, dynamic>.from((_media[path] as Map?) ?? {});
      final id = known['id'] as String? ?? newOperationId();
      if (known['ready'] != true) {
        _media[path] = {'id': id, 'ready': false};
        await _saveToStorage();
        await cloud!.upload(uid, path, kind, id);
        _media[path] = {'id': id, 'ready': true};
        await _saveToStorage();
      }
      return id;
    }

    for (final path in r.memoryPhotoPaths) {
      photos.add(await mediaId(path, 'photo'));
    }
    final voice = r.voiceNotePath == null
        ? null
        : await mediaId(r.voiceNotePath!, 'voice');
    final result = _toJson(r)
      ..remove('memoryPhotoPaths')
      ..remove('voiceNotePath');
    result['photoIds'] = photos;
    result['voiceId'] = voice;
    result['date'] =
        '${r.date.year.toString().padLeft(4, '0')}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
    final time = r.eventDateTime;
    result['time'] =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    result['createdAt'] = r.createdAt.toUtc().toIso8601String();
    return result;
  }

  Future<ReminderModel> _local(Map<String, dynamic> remote, String uid) async {
    final data = Map<String, dynamic>.from(remote['data'] as Map);
    Future<String> pathFor(String id) async {
      for (final e in _media.entries) {
        if ((e.value as Map)['id'] == id &&
            (e.value as Map)['ready'] == true &&
            await File(e.key).exists()) {
          return e.key;
        }
      }
      final path = await cloud!.download(uid, id);
      _media[path] = {'id': id, 'ready': true};
      return path;
    }

    final paths = <String>[];
    for (final id in data['photoIds'] as List) {
      paths.add(await pathFor(id as String));
    }
    data['memoryPhotoPaths'] = paths;
    data['voiceNotePath'] = data['voiceId'] == null
        ? null
        : await pathFor(data['voiceId'] as String);
    return _fromJson(data);
  }

  Future<void>? _syncing;
  Future<void> sync() {
    if (cloud == null || _uid == null) return Future.value();
    if (_syncing != null) return _syncing!;
    final epoch = _epoch;
    final future = _serial(() async {
      if (epoch != _epoch) return;
      final uid = _uid!;
      syncStatus.value = 'Syncing with cloud…';
      try {
        await _loadFromStorage();
        await _saveToStorage();
        await cloud!.request(uid, 'GET', '/v1/profile');
        final prefs = await SharedPreferences.getInstance();
        final remotePrefs = await cloud!.request(uid, 'GET', '/v1/preferences');
        if (_pendingAlert != null) {
          final saved = await cloud!.request(uid, 'PUT', '/v1/preferences', {
            'alertsEnabled': _pendingAlert,
            'baseVersion': _preferenceVersion ?? remotePrefs['version'],
          });
          _preferenceVersion = saved['version'] as int;
          _pendingAlert = null;
        } else {
          _preferenceVersion = remotePrefs['version'] as int;
          if (!await prefs.setBool(
            alertsKey,
            remotePrefs['alertsEnabled'] as bool,
          )) {
            throw StateError('Could not cache preferences');
          }
        }
        await _saveToStorage();
        String? warning;
        for (final id in _pending.keys.toList()) {
          if (epoch != _epoch) return;
          if (_conflicts.containsKey(id)) continue;
          final op = Map<String, dynamic>.from(_pending[id] as Map);
          try {
            if (!op.containsKey('body')) {
              op['body'] = {
                'operationId': op['operationId'],
                'baseVersion': op['baseVersion'],
                'data': op['local'] == null
                    ? null
                    : await _wire(
                        _fromJson(
                          Map<String, dynamic>.from(op['local'] as Map),
                        ),
                        uid,
                      ),
              };
              _pending[id] = op;
              await _saveToStorage();
            }
            final saved = await cloud!.request(
              uid,
              'PUT',
              '/v1/reminders/${Uri.encodeComponent(id)}',
              Map<String, dynamic>.from(op['body'] as Map),
            );
            if (epoch != _epoch) return;
            _versions[id] = saved['version'];
            _pending.remove(id);
            await _saveToStorage();
          } on CloudFailure catch (e) {
            if (e.status == 409) {
              _conflicts[id] = {'local': op['local'], 'reason': e.code};
              await _saveToStorage();
            } else {
              warning = _message(e);
            }
          }
        }
        final snapshot = await cloud!.request(uid, 'GET', '/v1/reminders');
        if (epoch != _epoch) return;
        for (final value in snapshot['reminders'] as List) {
          final remote = Map<String, dynamic>.from(value as Map);
          final id = remote['id'] as String;
          if (_pending.containsKey(id)) {
            if (_conflicts.containsKey(id)) {
              (_conflicts[id] as Map)['remote'] = remote;
            }
            continue;
          }
          if (remote['deleted'] == true) {
            _database.removeWhere((r) => r.id == id);
            _versions[id] = remote['version'];
            continue;
          }
          try {
            final local = await _local(remote, uid);
            if (epoch != _epoch) return;
            _database.removeWhere((r) => r.id == id);
            _database.add(local);
            _versions[id] = remote['version'];
          } on CloudFailure catch (e) {
            warning = _message(e);
          }
        }
        await _saveToStorage();
        syncStatus.value = _conflicts.isNotEmpty
            ? 'Sync conflict: review saved versions'
            : warning ??
                  (_pending.isEmpty
                      ? 'Cloud sync complete'
                      : 'Changes saved locally; sync pending');
      } catch (e) {
        if (epoch == _epoch) syncStatus.value = _message(e);
      }
    });
    _syncing = future.whenComplete(() => _syncing = null);
    return _syncing!;
  }

  String _message(Object e) {
    if (e is CloudFailure) {
      if (e.code == 'cloud_access_suspended') {
        return 'Cloud access is suspended. Local data is safe; contact YaadX support.';
      }
      if (e.code == 'media_storage_not_configured') {
        return 'Media backup needs cloud storage setup. Local files are safe.';
      }
      if (e.status == 401) {
        return 'Cloud sync needs sign-in. Local changes are safe.';
      }
      if (e.status == 409) {
        return 'Notification settings changed on another device. Review sync settings.';
      }
      if (e.status == 400) {
        return 'Some data could not sync (${e.code}). Local data is safe.';
      }
    }
    return 'Offline or server unavailable. Changes saved on this device; tap Retry.';
  }

  // Explicit user choice; conflict copies stay archived instead of being discarded.
  Future<void> resolveConflict(String id, {required bool keepLocal}) =>
      _serial(() async {
        final conflict = _conflicts[id] as Map?;
        if (conflict == null || conflict['remote'] == null) return;
        final prefs = await SharedPreferences.getInstance();
        if (!await prefs.setString(
          '${_storageKey}_conflict_backup_${newOperationId()}',
          jsonEncode(conflict),
        )) {
          throw StateError('Could not preserve conflict');
        }
        final remote = Map<String, dynamic>.from(conflict['remote'] as Map);
        if (keepLocal) {
          if (remote['deleted'] == true) {
            final raw = conflict['local'];
            if (raw != null) {
              final restored = _fromJson(
                Map<String, dynamic>.from(raw as Map),
              ).copyWith(id: newOperationId());
              _database.removeWhere((r) => r.id == id);
              _database.add(restored);
              _queue(restored.id, restored);
            }
            _pending.remove(id);
          } else {
            _versions[id] = remote['version'];
            _queue(
              id,
              conflict['local'] == null
                  ? null
                  : _fromJson(
                      Map<String, dynamic>.from(conflict['local'] as Map),
                    ),
            );
          }
        } else {
          final local = remote['deleted'] == true
              ? null
              : await _local(remote, _uid!);
          _database.removeWhere((r) => r.id == id);
          if (local != null) _database.add(local);
          _versions[id] = remote['version'];
          _pending.remove(id);
        }
        _conflicts.remove(id);
        await _saveToStorage();
      });
  Future<void> resolvePreferences({required bool keepLocal}) =>
      _serial(() async {
        if (cloud == null || _uid == null) return;
        final remote = await cloud!.request(_uid!, 'GET', '/v1/preferences');
        _preferenceVersion = remote['version'] as int;
        if (!keepLocal) {
          _pendingAlert = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(alertsKey, remote['alertsEnabled'] as bool);
        }
        await _saveToStorage();
      });
  int? _preferenceVersion;
  bool? _pendingAlert;
  String get alertsKey => '${_storageKey}_alerts_enabled';
  Future<void> setAlertsPreference(bool enabled) => _serial(() async {
    await _loadFromStorage();
    _pendingAlert = enabled;
    await _saveToStorage();
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(alertsKey, enabled)) {
      throw StateError('Could not save notification preference');
    }
  });
}
