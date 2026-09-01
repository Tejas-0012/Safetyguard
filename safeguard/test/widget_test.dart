// Basic smoke test for the SafeGuard app.
//
// This replaces the default Flutter counter-app template, which referenced
// widgets ('0', '1', a '+' icon) that don't exist in this project and would
// always fail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:safeguard/main.dart';
import 'package:safeguard/providers/auth_provider.dart';
import 'package:safeguard/providers/emergency_provider.dart';
import 'package:safeguard/providers/location_provider.dart';
import 'package:safeguard/services/auth_service.dart';
import 'package:safeguard/services/api_service.dart';
import 'package:safeguard/services/location_service.dart';

void main() {
  testWidgets('App boots and shows the splash screen', (
    WidgetTester tester,
  ) async {
    final authService = AuthService();
    final apiService = ApiService();
    final locationService = LocationService();

    // Mirrors the provider setup in main.dart so screens that call
    // Provider.of<...>() don't throw during the test.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
          ChangeNotifierProvider(create: (_) => EmergencyProvider(apiService)),
          ChangeNotifierProvider(
            create: (_) => LocationProvider(locationService),
          ),
        ],
        child: const MyApp(),
      ),
    );

    // Splash screen should render immediately, before the delayed navigation.
    expect(find.text('SAFE GUARD'), findsOneWidget);
    expect(find.text('Your Safety, Our Priority'), findsOneWidget);
  });
}
