import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/announcements_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/messaging_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const HecConnectApp());
}

class HecConnectApp extends StatelessWidget {
  const HecConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: NotificationService.messengerKey,
        title: 'HEC Connect',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SplashScreen(),
        routes: {
          '/home':            (context) => const HomeScreen(),
          '/annonces':        (context) => const AnnouncementsScreen(),
          '/emploi-du-temps': (context) => const ScheduleScreen(),
          '/messagerie':      (context) => const MessagingScreen(),
          '/profil':          (context) => const ProfileScreen(),
        },
      ),
    );
  }
}