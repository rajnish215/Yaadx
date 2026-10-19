import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'add_reminder_screen.dart';
import 'reminder_controller.dart';
import 'notification_service.dart';

class CelebrateScreen extends StatefulWidget {
  const CelebrateScreen({super.key, required this.reminderId});
  final String reminderId;
  @override
  State<CelebrateScreen> createState() => _CelebrateScreenState();
}

class _CelebrateScreenState extends State<CelebrateScreen> {
  bool _busy = false;
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete this action. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReminderController>();
    final matches = controller.reminders.where(
      (r) => r.id == widget.reminderId,
    );
    if (matches.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Celebrate')),
        body: const Center(child: Text('This event is no longer available.')),
      );
    }
    final event = matches.first;
    return Scaffold(
      appBar: AppBar(title: Text('Celebrate with ${event.name}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.celebration, size: 64, color: Color(0xffC8453A)),
          const SizedBox(height: 20),
          Text(
            '${event.eventType} · ${event.name}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            '${event.relation} · ${event.time}${event.repeatYearly ? ' · Yearly' : ''}',
          ),
          if (event.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(event.note),
            ),
          if (event.memoryCaption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(event.memoryCaption),
            ),
          if (event.memoryPhotoPaths.isNotEmpty)
            SizedBox(
              height: 160,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final path in event.memoryPhotoPaths)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.file(
                        File(path),
                        width: 150,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => const SizedBox(
                          width: 150,
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => _run(
                    () => NotificationService.shareMemoryForReminder(event.id),
                  ),
            icon: const Icon(Icons.share),
            label: const Text('Share wish and photos'),
          ),
          if (event.voiceNotePath != null)
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _run(() async {
                      if (!await File(event.voiceNotePath!).exists()) {
                        throw StateError('Missing recording');
                      }
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(event.voiceNotePath!)],
                          title: 'Voice wish for ${event.name}',
                        ),
                      );
                    }),
              icon: const Icon(Icons.mic),
              label: const Text('Share recorded voice wish'),
            ),
          const Text(
            'Choose the app and recipient, then send your wish. Sharing does not confirm delivery.',
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            title: const Text('I have sent my wish'),
            value: event.messageSent,
            onChanged: _busy
                ? null
                : (value) => _run(
                    () => controller.updateReminder(
                      event.copyWith(messageSent: value ?? false),
                    ),
                  ),
          ),
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => AddReminderScreen(reminder: event),
                    ),
                  ),
            icon: const Icon(Icons.edit),
            label: const Text('Edit event'),
          ),
        ],
      ),
    );
  }
}
