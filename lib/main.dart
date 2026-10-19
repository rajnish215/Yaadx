import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reminder/reminder_service.dart';
import 'reminder/celebrate_screen.dart';

import 'firebase_options.dart';
import 'auth/controllers/auth_controller.dart';

import 'splash/splash_screen.dart';
import 'home/home_screen.dart';
import 'calendar/calendar_screen.dart';
import 'reminder/reminder_screen.dart';
import 'reminder/reminder_controller.dart';
import 'reminder/notification_service.dart';
import 'home/widgets/bottom_navbar.dart';
import 'profile/profile_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await ReminderService().useAccount(
    FirebaseAuth.instance.currentUser?.uid,
    migrateLegacy: true,
  );

  // Initialize local notifications
  await NotificationService.initialize();

  // Launch app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ReminderController()),
        ChangeNotifierProvider(create: (_) => AuthController()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'YaadX',
      home: const SplashScreen(),
    );
  }
}

// ===============================
// MAIN SCREEN
// ===============================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    _initialLoad = context.read<ReminderController>().loadReminders();
    NotificationService.onReminderOpened = _openReminder;
    _initialLoad.then((_) async {
      String? launch;
      try {
        launch = await NotificationService.takeLaunchReminder();
      } catch (_) {
        /* No native launch event. */
      }
      final id = launch ?? NotificationService.pendingReminderId;
      NotificationService.pendingReminderId = null;
      if (id != null && mounted) _openReminder(id);
    }, onError: (Object _) {});
  }

  void _openReminder(String id) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CelebrateScreen(reminderId: id),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    NotificationService.onReminderOpened = null;
    super.dispose();
  }

  void _retryLoad() {
    setState(() {
      _initialLoad = context.read<ReminderController>().loadReminders();
    });
  }

  final List<Widget> _pages = const [
    HomeScreen(),
    CalendarScreen(),
    ReminderScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initialLoad,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Could not load your reminders.'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _retryLoad,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return _pages[_currentIndex];
        },
      ),
      bottomNavigationBar: BottomNavbar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
