import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'services/api_client.dart';
import 'services/notification_service.dart';
import 'screens/user/auth_screen.dart';
import 'screens/admin/dashboard_screen.dart';
import 'screens/conductor/home_screen.dart' as conductor;
import 'screens/cliente/home_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Widget _homeScreenByRole() {
  final rol = ApiClient.instance.rol;
  switch (rol) {
    case 'admin':
      return const DashboardScreen();
    case 'conductor':
      return const conductor.HomeScreen();
    case 'cliente':
      return const ClienteHomeScreen();
    default:
      return const AuthScreen();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {
    // Fallback: intentar sin options (Android/iOS usan google-services.json)
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } catch (_) {
      // Firebase no disponible en este entorno
    }
  }
  await ApiClient.instance.init();
  unawaited(NotificationService.instance.init());
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CargaExpress',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      home: ApiClient.instance.token != null
          ? _homeScreenByRole()
          : const AuthScreen(),
    );
  }
}
