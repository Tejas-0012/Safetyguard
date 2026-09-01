import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

// Providers
import 'providers/auth_provider.dart';
import 'providers/emergency_provider.dart';
import 'providers/location_provider.dart';

// Services
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/sms_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/emergency_mode_screen.dart';
import 'screens/emergency_monitoring_screen.dart';
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully!');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  // ✅ Create separate services
  final authService = AuthService();
  final apiService = ApiService(); // ✅ Create ApiService separately
  final locationService = LocationService();
  final smsService = SmsService();

  try {
    await NotificationService.initialize();
  } catch (e) {
    print('⚠️ NotificationService.initialize() failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(
          create: (_) => EmergencyProvider(apiService),
        ), // ✅ Pass ApiService
        ChangeNotifierProvider(
          create: (_) => LocationProvider(locationService),
        ),
        Provider<SmsService>.value(value: smsService),
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
      title: 'SafeGuard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: GoogleFonts.poppins().fontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1A237E),
          primary: const Color(0xFF1A237E),
          secondary: const Color(0xFF0D47A1),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/contacts': (context) => const ContactsScreen(),
        '/emergency': (context) => const EmergencyModeScreen(),
        '/monitor': (context) => const EmergencyMonitoringScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}
