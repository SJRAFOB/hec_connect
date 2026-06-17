// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/presence_service.dart';
import '../models/user_model.dart';
import 'student_home_screen.dart';
import 'teacher_home_screen.dart';
import 'admin_home_screen.dart';
import 'staff_home_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _setOnline());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        PresenceService.setOnline(uid);
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        PresenceService.setOffline(uid);
        break;
      default:
        break;
    }
  }

  void _setOnline() {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != null) PresenceService.setOnline(uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    if (user == null) return const LoginScreen();

    switch (user.role) {
      case UserRole.student:
        return const StudentHomeScreen();
      case UserRole.teacher:
        return const TeacherHomeScreen();
      case UserRole.admin:
        return const AdminHomeScreen();
      case UserRole.staff:
        return const StaffHomeScreen();
    }
  }
}
