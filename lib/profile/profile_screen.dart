import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/controllers/auth_controller.dart';
import '../calendar/calendar_screen.dart';
import '../login/login_screen.dart';
import '../reminder/notification_service.dart';
import '../reminder/reminder_controller.dart';
import 'edit_profile_screen.dart';
import 'notification_settings_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

const profileAccent = Color(0xffC8453A);
const profileBackground = Color(0xffFFF7F6);

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_loggingOut) {
      context.read<AuthController>().reloadUser().catchError((Object _) {});
    }
  }

  bool _loggingOut = false;

  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of YaadX?'),
        content: const Text(
          'Your saved events stay on this device. Alerts will pause until you sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    final auth = context.read<AuthController>();
    final reminders = context.read<ReminderController>();
    try {
      await NotificationService.cancelAll();
      await auth.logout();
      reminders.resetSession();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not log out. Please try again.')),
      );
      // Restore alerts if sign-out failed after they were cancelled.
      try {
        await reminders.loadReminders();
      } catch (_) {
        /* Retry on next load. */
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final name = auth.userName.trim();
    final email = auth.userEmail;
    final count = context.watch<ReminderController>().totalReminders;
    return Scaffold(
      backgroundColor: profileBackground,
      appBar: AppBar(
        backgroundColor: profileBackground,
        title: const Text('Profile'),
      ),
      body: AbsorbPointer(
        absorbing: _loggingOut,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: CircleAvatar(
                radius: 48,
                backgroundColor: profileAccent,
                child: Text(
                  name.isEmpty ? 'Y' : name.characters.first.toUpperCase(),
                  style: const TextStyle(fontSize: 40, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              name.isEmpty ? 'Your profile' : name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              auth.isEmailVerified
                  ? 'Email verified'
                  : 'Email verification pending',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _tile(
              Icons.person_outline,
              'Edit Profile',
              'Update your name and email',
              () => _open(const EditProfileScreen()),
            ),
            _tile(
              Icons.favorite_outline,
              'Important Dates',
              '$count saved event${count == 1 ? '' : 's'}',
              () => _open(
                Scaffold(
                  appBar: AppBar(title: const Text('Important Dates')),
                  body: const CalendarScreen(),
                ),
              ),
            ),
            _tile(
              Icons.notifications_none,
              'Notifications',
              'Manage event alerts and permissions',
              () => _open(const NotificationSettingsScreen()),
            ),
            _tile(
              Icons.settings_outlined,
              'Settings',
              'Password, preferences and app information',
              () => _open(const SettingsScreen()),
            ),
            _tile(
              Icons.help_outline,
              'Help & Support',
              'Answers and feedback',
              () => _open(const HelpScreen()),
            ),
            _tile(
              Icons.logout,
              _loggingOut ? 'Logging out…' : 'Logout',
              'Sign out of this account',
              _logout,
            ),
            if (_loggingOut) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _tile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon, color: profileAccent),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );
}
