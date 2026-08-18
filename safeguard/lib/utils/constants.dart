import 'package:flutter/material.dart';

class AppConstants {
  // API
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android Emulator
  // static const String baseUrl = 'http://localhost:5000/api'; // iOS

  // Shared Preferences Keys
  static const String tokenKey = 'token';
  static const String userKey = 'user';

  // Emergency Status
  static const String emergencyActive = 'active';
  static const String emergencyResolved = 'resolved';
  static const String emergencyCancelled = 'cancelled';

  // Notification Channels
  static const String emergencyChannel = 'emergency_channel';
  static const String emergencyChannelName = 'Emergency Notifications';

  // Location Settings
  static const int locationUpdateInterval = 5; // seconds
  static const int locationDistanceFilter = 10; // meters

  // SOS Settings
  static const int sosCooldownSeconds = 30;
  static const int maxEmergencyContacts = 10;

  // UI Constants
  static const double sosButtonSize = 120;
  static const double sosButtonRadius = 60;
  static const double defaultMapZoom = 15.0;
}

class AppColors {
  static const primary = Color(0xFF1A237E);
  static const secondary = Color(0xFF0D47A1);
  static const accent = Color(0xFF01579B);
  static const danger = Color(0xFFFF0000);
  static const success = Color(0xFF00C853);
  static const warning = Color(0xFFFFC107);
  static const background = Color(0xFFF5F5F5);
}

class AppStrings {
  // Auth
  static const String loginTitle = 'Welcome Back!';
  static const String registerTitle = 'Create Profile';
  static const String welcomeSubtitle = 'Your Safety, Our Priority';

  // Emergency
  static const String emergencyActive = '🚨 EMERGENCY MODE ACTIVE';
  static const String youAreSafe = 'You are Safe • Monitoring Active';
  static const String sosButton = 'SOS';

  // Messages
  static const String noContacts = 'No Emergency Contacts';
  static const String addContact = 'Add Emergency Contact';
  static const String contactAdded = 'Contact added successfully!';
  static const String contactDeleted = 'Contact deleted successfully!';

  // Errors
  static const String locationPermissionDenied = 'Location permission denied';
  static const String networkError = 'Network connection error';
  static const String emergencyFailed = 'Failed to start emergency';
  static const String stopEmergencyConfirm = 'Are you sure you are safe?';
}
