import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../reminder/notification_service.dart';
import '../reminder/reminder_controller.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _busy = false;
  bool _enabled = true;
  bool _permission = false;
  bool _exact = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final enabled = await NotificationService.alertsEnabled();
      final permission = await NotificationService.permissionGranted();
      final exact = await NotificationService.canScheduleExact();
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _permission = permission;
        _exact = exact;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not read notification settings.';
        });
      }
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update notifications. Please try again.'),
          ),
        );
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggle(bool enabled) async {
    final controller = context.read<ReminderController>();
    await _run(() async {
      if (enabled && !await NotificationService.requestPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Allow notifications in phone settings to receive alerts.',
              ),
            ),
          );
        }
        return;
      }
      await NotificationService.setAlertsEnabled(enabled);
      if (enabled) await controller.loadReminders();
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReminderController>();
    final reminders = [...controller.reminders]
      ..sort((a, b) => a.eventDateTime.compareTo(b.eventDateTime));
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  leading: const Icon(Icons.alarm),
                  title: Text(
                    _exact
                        ? 'Exact alarm access allowed'
                        : 'Exact alarm access not allowed',
                  ),
                  subtitle: const Text(
                    'Allow Alarms & reminders for scheduled timing. Without access, Android may delay alerts. Force-stop, Do Not Disturb and battery settings can still affect delivery.',
                  ),
                  trailing: _exact ? const Icon(Icons.check) : null,
                ),
                if (!_exact)
                  OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(NotificationService.requestExact),
                    child: const Text('Allow exact alarms'),
                  ),

                if (_error != null) ...[
                  Text(_error!),
                  TextButton(onPressed: _refresh, child: const Text('Retry')),
                ],
                SwitchListTile(
                  title: const Text('Event alerts on this device'),
                  subtitle: const Text(
                    'Pause all alerts without changing individual event switches.',
                  ),
                  value: _enabled,
                  onChanged: _busy || _error != null ? null : _toggle,
                ),
                ListTile(
                  leading: Icon(
                    _permission
                        ? Icons.check_circle_outline
                        : Icons.notifications_off_outlined,
                  ),
                  title: Text(
                    _permission
                        ? 'Phone notifications allowed'
                        : 'Phone notifications blocked',
                  ),
                  subtitle: const Text(
                    'Your phone controls whether YaadX can show alerts.',
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    if (!_permission)
                      OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => _run(() async {
                                await NotificationService.requestPermission();
                              }),
                        child: const Text('Allow notifications'),
                      ),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => _run(NotificationService.openSystemSettings),
                      child: const Text('Open phone settings'),
                    ),
                  ],
                ),
                const Divider(height: 32),
                const Text(
                  'Saved event alerts',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (!_enabled)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'All alerts are paused. Your event preferences are preserved.',
                    ),
                  ),
                if (reminders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No saved events yet. Add one in Reminders.'),
                  ),
                for (final reminder in reminders)
                  SwitchListTile(
                    title: Text('${reminder.name} · ${reminder.eventType}'),
                    subtitle: Text(
                      '${reminder.date.day}/${reminder.date.month}/${reminder.date.year} · ${reminder.time}'
                      '${reminder.isCompleted
                          ? ' · Completed'
                          : reminder.eventDateTime.isBefore(DateTime.now())
                          ? ' · Past event'
                          : ''}',
                    ),
                    value: reminder.notificationEnabled,
                    onChanged: _busy || !_enabled || reminder.isCompleted
                        ? null
                        : (_) => _run(
                            () => controller.toggleNotification(reminder.id),
                          ),
                  ),
                if (_busy) const Center(child: CircularProgressIndicator()),
              ],
            ),
    );
  }
}
