import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'pages/welcome_page.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

// Handler untuk notifikasi saat aplikasi berada di background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Pesan FCM diterima: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Mendaftarkan background handler FCM.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Inisialisasi notifikasi.
  await NotificationService.instance.initialize();

  runApp(const UniFlowApp());
}

class UniFlowApp extends StatelessWidget {
  const UniFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'UniFlow',
      theme: AppTheme.theme,
      home: const WelcomePage(),
    );
  }
}
