
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

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
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize local notifications
  await NotificationService.initialize();

  // Launch app
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => ReminderController(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthController(),
        ),
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

  final List<Widget> _pages = const [
    HomeScreen(),
    CalendarScreen(),
    ReminderScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
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
