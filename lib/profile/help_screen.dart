import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final _feedback = TextEditingController();
  bool _sharing = false;
  @override
  void dispose() {
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final message = _feedback.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe your question or issue first.')),
      );
      return;
    }
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'YaadX feedback',
          text: 'YaadX feedback\n\n$message',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open sharing options. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Help & Support')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const ExpansionTile(
          title: Text('How do I save an important date?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Open Reminders and tap Add Reminder. Enter the person, event date and a future time, then save. You can add photos and a caption too.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Why did I not receive an alert?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Open Profile → Notifications. Turn on event alerts, allow phone notification permission and check the switch for the event. The date and time must be in the future. Phone battery restrictions can delay alerts.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Are wishes sent automatically?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Currently, Share Memory opens your phone’s sharing options. Select an app and recipient, then send. Saved voice notes can be played in Event Preparation; they are not included in photo sharing.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('Will my events survive logout?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Yes. Sign in to the same account on this device to load them again. Alerts pause while logged out. Uninstalling or clearing app data can remove local events and memories.',
              ),
            ),
          ],
        ),
        const ExpansionTile(
          title: Text('How do I change my email or password?'),
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Use Edit Profile → Change email and confirm your current password. Verify the link sent to your new email. For a password change, use Settings → Reset password.',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Share feedback',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Describe what happened and what you expected. Do not include your password. Choose who to send it to in the sharing screen.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _feedback,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Your question or issue',
            border: OutlineInputBorder(),
          ),
        ),
        FilledButton.icon(
          onPressed: _sharing ? null : _share,
          icon: const Icon(Icons.share),
          label: Text(_sharing ? 'Opening…' : 'Share feedback'),
        ),
      ],
    ),
  );
}
