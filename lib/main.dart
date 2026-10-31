import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reminder/reminder_service.dart';
import 'backend/cloud_api.dart';
import 'backend/sync_screen.dart';
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

  const apiUrl = String.fromEnvironment('YAADX_API_URL');
  if (apiUrl.isNotEmpty) {
    ReminderService().cloud = CloudApi(
      baseUrl: apiUrl,
      currentUid: () => FirebaseAuth.instance.currentUser?.uid,
      token: (force) async =>
          FirebaseAuth.instance.currentUser?.getIdToken(force),
    );
  }
  await ReminderService().useAccount(
    FirebaseAuth.instance.currentUser?.uid,
    migrateLegacy: true,
  );

  // Initialize local notifications
  try {
    await NotificationService.initialize();
  } catch (_) {
    // Saved events remain available; the controller reports alert failures.
  }

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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onReminderOpened = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ReminderController>().syncCloud();
    }
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
          return Column(
            children: [
              const SafeArea(bottom: false, child: SyncBanner()),
              Consumer<ReminderController>(
                builder: (context, controller, _) {
                  final warning = controller.alertWarning;
                  if (warning == null) return const SizedBox.shrink();
                  return MaterialBanner(
                    content: Text(warning),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          try {
                            await controller.loadReminders();
                          } catch (_) {}
                        },
                        child: const Text('Retry alerts'),
                      ),
                    ],
                  );
                },
              ),
              Expanded(child: _pages[_currentIndex]),
            ],
          );
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
