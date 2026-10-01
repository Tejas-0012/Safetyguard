import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

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
import 'services/sos_trigger_service.dart';
import 'services/storage_service.dart';
import 'services/native_bridge_service.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/contacts_screen.dart';
import 'screens/emergency_mode_screen.dart';
import 'screens/emergency_monitoring_screen.dart';
import 'screens/profile_screen.dart';

// ✅ GLOBAL — accessible from _MyAppState
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ✅ GLOBAL — native bridge channel
const MethodChannel _nativeChannel = MethodChannel(
  'com.example.safeguard/native',
);

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

  // ✅ Create services
  final storageService = StorageService();
  final authService = AuthService();
  final apiService = ApiService();
  final locationService = LocationService();
  final smsService = SmsService();
  final sosTriggerService = SosTriggerService(
    apiService: apiService,
    smsService: smsService,
    storage: storageService,
  );

  try {
    await NotificationService.initialize();
  } catch (e) {
    print('⚠️ NotificationService.initialize() failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        ChangeNotifierProvider(create: (_) => EmergencyProvider(apiService)),
        ChangeNotifierProvider(
          create: (_) =>
              LocationProvider(locationService, storage: storageService),
        ),
        Provider<SmsService>.value(value: smsService),
        Provider<StorageService>.value(value: storageService),
        Provider<SosTriggerService>.value(value: sosTriggerService),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupNativeHandlers();
    _checkTileLaunch();
  }

  void _setupNativeHandlers() {
    // Called when tile is tapped while app is already running
    NativeBridgeService.onOpenEmergencyMode(() {
      print('📱 Native: openEmergencyMode received');
      _goToEmergencyMode();
    });
  }

  Future<void> _checkTileLaunch() async {
    // Wait for app to fully initialize
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    try {
      final fromTile = await NativeBridgeService.wasLaunchedFromTile();
      print('📱 Native: wasLaunchedFromTile = $fromTile');

      if (fromTile) {
        await NativeBridgeService.clearTileLaunch();
        _goToEmergencyMode();
      }
    } catch (e) {
      print('NativeBridge error: $e');
    }
  }

  void _goToEmergencyMode() {
    if (!mounted) return;
    navigatorKey.currentState?.pushNamed('/emergency');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // ✅ CRITICAL
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
