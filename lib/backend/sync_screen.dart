import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../reminder/reminder_controller.dart';
import '../reminder/reminder_service.dart';

class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    return ValueListenableBuilder<String>(
      valueListenable: service.syncStatus,
      builder: (context, status, _) => Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: ListTile(
          dense: true,
          leading: Icon(
            service.cloudEnabled ? Icons.cloud_outlined : Icons.phone_android,
          ),
          title: Text(
            service.cloudEnabled
                ? status
                : 'Saved on this device • cloud not configured',
            style: const TextStyle(fontSize: 12),
          ),
          trailing: service.cloudEnabled
              ? TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const SyncScreen()),
                  ),
                  child: const Text('Sync'),
                )
              : null,
        ),
      ),
    );
  }
}

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  bool busy = false;
  Future<void> run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
      if (mounted) await context.read<ReminderController>().syncCloud();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not sync. Your local data is retained.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = ReminderService();
    return Scaffold(
      appBar: AppBar(title: const Text('Cloud sync')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<String>(
            valueListenable: service.syncStatus,
            builder: (_, value, _) => Text(value),
          ),
          const Text(
            'Local changes and pre-cloud backups stay on this device. Photos and voice notes need cloud media storage to back up.',
          ),
          FilledButton(
            onPressed: busy ? null : () => run(() async {}),
            child: Text(busy ? 'Syncing…' : 'Retry sync'),
          ),
          for (final conflict in service.conflicts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Event ${conflict['id']}'),
                    Text(
                      'This device: ${conflict['local']?['name'] ?? 'Deleted'} • ${conflict['local']?['date'] ?? ''}',
                    ),
                    Text(
                      'Cloud: ${conflict['remote']?['data']?['name'] ?? 'Not loaded'} • ${conflict['remote']?['deleted'] == true ? 'Deleted' : conflict['remote']?['data']?['date'] ?? ''}',
                    ),
                    const Text(
                      'Choose which version to keep. A copy of the conflict is preserved locally.',
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => service.resolveConflict(
                                    conflict['id'] as String,
                                    keepLocal: true,
                                  ),
                                ),
                          child: const Text('Keep this device'),
                        ),
                        TextButton(
                          onPressed: busy
                              ? null
                              : () => run(
                                  () => service.resolveConflict(
                                    conflict['id'] as String,
                                    keepLocal: false,
                                  ),
                                ),
                          child: const Text('Use cloud version'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          const Text('If notification settings changed on another device:'),
          TextButton(
            onPressed: busy
                ? null
                : () => run(() => service.resolvePreferences(keepLocal: true)),
            child: const Text('Keep this device’s notification settings'),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => run(() => service.resolvePreferences(keepLocal: false)),
            child: const Text('Use cloud notification settings'),
          ),
        ],
      ),
    );
  }
}
