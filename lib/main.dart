import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:get/get.dart';
import 'firebase_options.dart';
import 'splash.dart';
import 'auth-page.dart';
import 'register.dart';
import 'Forgotpass.dart';
import 'Homepage.dart';
import 'dependency_injection.dart';

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize dependency injection
  DependencyInjection.init();

  runApp(const Craft());
}

class Craft extends StatelessWidget {
  const Craft({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      navigatorKey: navigatorKey,
      title: "UniCraft",
      debugShowCheckedModeBanner: false,
      home: const Splash(),
      routes: {
        '/auth': (context) => const AuthPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const Homepage(),
      },
      theme: ThemeData(
        primarySwatch: Colors.teal,
        primaryColor: const Color(0xff1b6e70),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff1b6e70),
        ),
        useMaterial3: true,
      ),
    );
  }
}
