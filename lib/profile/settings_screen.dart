import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/controllers/auth_controller.dart';
import 'notification_settings_screen.dart';
import '../reminder/reminder_service.dart';
import '../backend/sync_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _resetPassword() async {
    setState(() => _sending = true);
    final auth = context.read<AuthController>();
    final error = await auth.resetPassword(auth.userEmail);
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = error == null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Password reset link sent. Check your email.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<AuthController>().userEmail;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notification preferences'),
            subtitle: const Text('Enable alerts and manage individual events'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const NotificationSettingsScreen(),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: const Text('Reset password'),
            subtitle: Text(email),
            trailing: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(),
                  )
                : null,
            enabled: !_sending && !_sent && email.isNotEmpty,
            onTap: _resetPassword,
          ),
          if (_sent)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Reset link sent. Follow the link in your email to choose a new password.',
              ),
            ),
          const Divider(),
          ValueListenableBuilder<String>(
            valueListenable: ReminderService().syncStatus,
            builder: (context, status, _) => ListTile(
              leading: const Icon(Icons.phone_android),
              title: const Text('Your saved data'),
              subtitle: Text(
                ReminderService().cloudEnabled
                    ? '$status. Events sync through your connected account. Photos and recordings need configured cloud storage and a successful upload. Unsynced data stays on this device and can be lost if you uninstall or clear app data.'
                    : 'Saved on this device only. Cloud sync is not configured for this build. Uninstalling or clearing app data can remove events, photos and recordings.',
              ),
              trailing: ReminderService().cloudEnabled
                  ? const Icon(Icons.chevron_right)
                  : null,
              onTap: ReminderService().cloudEnabled
                  ? () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const SyncScreen(),
                      ),
                    )
                  : null,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About YaadX'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAboutDialog(
              context: context,
              applicationName: 'YaadX',
              applicationIcon: const Icon(Icons.celebration, size: 40),
              children: [
                const Text(
                  'Remember the people and occasions that matter. Plan events, keep memories and share thoughtful wishes.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
