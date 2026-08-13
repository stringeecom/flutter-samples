import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'firebase_options.dart';

/// Initializes Firebase before a background FCM message is delivered.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint('Background notification: ${message.messageId} ${message.data}');
}

/// Initializes Firebase, installs the background handler, and starts the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

/// Root application for the Stringee chat sample.
class MyApp extends StatelessWidget {
  /// Creates the Stringee-branded Material application.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandRed = Color(0xFFEE2333);
    return MaterialApp(
      title: 'Stringee Chat Sample',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: brandRed),
        scaffoldBackgroundColor: const Color(0xFFF7F8FA),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E5EA)),
          ),
        ),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}
