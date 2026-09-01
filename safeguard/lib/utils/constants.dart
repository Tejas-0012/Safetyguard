import 'package:flutter/material.dart';

class AppConstants {
  // API
  // Single source of truth for the backend URL — ApiService and AuthService
  // both import this instead of hardcoding their own copy (previously they
  // had 3 different values across 3 files, which silently drifted apart).
  //
  // Using your machine's LAN IP so a physical Android device (needed for
  // real SMS sending) can reach the backend over WiFi. This changes if your
  // machine reconnects to WiFi or DHCP reassigns it — check with `ipconfig`
  // (Windows) and update here if requests start failing.
  static const String baseUrl = 'http://10.246.18.187:5000/api';

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
  static const Color primary = Color(0xFF1A237E);
  static const Color secondary = Color(0xFF0D47A1);
  static const Color accent = Color(0xFF01579B);
  static const Color danger = Color(0xFFFF0000);
  static const Color success = Color(0xFF00C853);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color background = Color(0xFFF5F5F5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF616161);
  static const Color lightGrey = Color(0xFFE0E0E0);

  // Gradient Colors
  static const Color gradientStart = Color(0xFF1A237E);
  static const Color gradientEnd = Color(0xFF0D47A1);

  // Status Colors
  static const Color safe = Color(0xFF4CAF50);
  static const Color emergency = Color(0xFFFF0000);
  static const Color warningStatus = Color(0xFFFFC107);
  static const Color monitoring = Color(0xFF2196F3);
}

class AppStrings {
  // Auth
  static const String loginTitle = 'Welcome Back!';
  static const String registerTitle = 'Create Profile';
  static const String welcomeSubtitle = 'Your Safety, Our Priority';
  static const String loginSubtitle = 'Sign in to continue to SafeGuard';
  static const String registerSubtitle = 'Set up your safety profile';

  // Emergency
  static const String emergencyActive = '🚨 EMERGENCY MODE ACTIVE';
  static const String youAreSafe = 'You are Safe • Monitoring Active';
  static const String sosButton = 'SOS';
  static const String emergencyAlert = '⚠️ Activate SOS?';
  static const String emergencyAlertDesc =
      'This will send an emergency alert to all your trusted contacts and start live location sharing.';
  static const String activateSOS = 'ACTIVATE SOS';
  static const String stopEmergency = 'STOP EMERGENCY';
  static const String stopEmergencyConfirm = 'Are you sure you are safe?';

  // Contacts
  static const String contactsTitle = 'Emergency Contacts';
  static const String noContacts = 'No Emergency Contacts';
  static const String noContactsDesc =
      'Add trusted contacts to notify during emergencies';
  static const String addContact = 'Add Emergency Contact';
  static const String addContactTitle = 'Add Emergency Contact';
  static const String editContactTitle = 'Edit Emergency Contact';
  static const String contactAdded = 'Contact added successfully!';
  static const String contactUpdated = 'Contact updated successfully!';
  static const String contactDeleted = 'Contact deleted successfully!';
  static const String deleteContactConfirm =
      'Are you sure you want to delete this contact?';

  // Profile
  static const String profileTitle = 'Profile';
  static const String fullName = 'Full Name';
  static const String phoneNumber = 'Phone Number';
  static const String emailAddress = 'Email Address';
  static const String memberSince = 'Member Since';
  static const String emergencyStatus = 'Emergency Status';

  // Location
  static const String locationTitle = 'Location';
  static const String locationTracking = 'Live Location Tracking';
  static const String locationUpdate = 'Location Update';

  // Errors
  static const String locationPermissionDenied = 'Location permission denied';
  static const String networkError = 'Network connection error';
  static const String emergencyFailed = 'Failed to start emergency';
  static const String loginFailed = 'Login failed';
  static const String registerFailed = 'Registration failed';
  static const String contactAddFailed = 'Failed to add contact';
  static const String contactDeleteFailed = 'Failed to delete contact';
  static const String profileUpdateFailed = 'Failed to update profile';

  // Buttons
  static const String sendOTP = 'SEND OTP';
  static const String verifyOTP = 'VERIFY OTP';
  static const String continueButton = 'CONTINUE';
  static const String registerButton = 'REGISTER';
  static const String loginButton = 'LOGIN';
  static const String logoutButton = 'LOGOUT';
  static const String cancelButton = 'CANCEL';
  static const String saveButton = 'SAVE';
  static const String updateButton = 'UPDATE';
  static const String deleteButton = 'DELETE';
  static const String addButton = 'ADD';
  static const String editButton = 'EDIT';

  // Navigation
  static const String home = 'Home';
  static const String contacts = 'Contacts';
  static const String profile = 'Profile';
  static const String settings = 'Settings';
  static const String history = 'History';
  static const String location = 'Location';

  // Messages
  static const String areYouSafe = 'Are you sure you are safe?';
  static const String yesImSafe = "YES, I'M SAFE";
  static const String newUser = 'New user? ';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String resendOTP = 'Resend OTP?';

  // Camera
  static const String captureImage = 'CAPTURE IMAGE';
  static const String startVideo = 'START VIDEO';
  static const String stopVideo = 'STOP VIDEO';
  static const String cameraError = 'Error capturing image';

  // Notification
  static const String emergencyAlertTitle = '⚠️ EMERGENCY ALERT';
  static const String emergencyAlertBody = 'has activated an SOS alert!';
  static const String viewLocation = 'VIEW LIVE LOCATION';
}
