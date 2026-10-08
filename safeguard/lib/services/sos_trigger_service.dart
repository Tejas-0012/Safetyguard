import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/contact_model.dart';
import '../models/emergency_model.dart';
import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/location_provider.dart';
import 'api_service.dart';
import 'sms_service.dart';
import 'storage_service.dart';

/// ============================================================
/// SosTriggerService
/// ============================================================
/// Single entry point for triggering SOS from ANY source:
/// - In-app SOS button
/// - Quick Settings Tile (Android native)
/// - Home Screen Widget (Android native)
/// - Shake Detection
/// - Bluetooth Button
/// ============================================================
class SosTriggerService {
  final ApiService _apiService;
  final SmsService _smsService;
  final StorageService _storage;

  SosTriggerService({
    required this._apiService,
    required SmsService smsService,
    required this._storage,
  }) : _smsService = smsService;

  // ============ MAIN ENTRY POINT ============
  /// Trigger SOS with default behavior (all contacts, no camera/video)
  /// Call this from any trigger source.
  Future<SosResult> trigger({
    BuildContext? context,
    List<EmergencyContact>? customContacts,
    bool shareCamera = false,
    bool shareVideo = false,
    bool silent =
        false, // if true, don't show dialogs (for background triggers)
  }) async {
    try {
      // ============ 1. GET LOCATION ============
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        // Fallback: use last known location
        final lastLoc = await _storage.getLastLocation();
        if (lastLoc != null) {
          position = Position(
            latitude: lastLoc['lat']!,
            longitude: lastLoc['lng']!,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      }

      if (position == null) {
        return SosResult(
          success: false,
          error: 'Unable to get location. Please enable GPS.',
        );
      }

      // Save last known location
      await _storage.saveLastLocation(position.latitude, position.longitude);

      // ============ 2. START EMERGENCY ON BACKEND ============
      final emergencyResponse = await _apiService.startEmergency({
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      if (emergencyResponse['success'] != true) {
        return SosResult(
          success: false,
          error: emergencyResponse['message'] ?? 'Failed to start emergency',
        );
      }

      final emergencyId =
          emergencyResponse['emergency']?['id'] ??
          emergencyResponse['emergency']?['_id'];

      if (emergencyId == null) {
        return SosResult(
          success: false,
          error: 'Emergency ID not returned by server',
        );
      }

      // ============ 3. USE RECEIVER LINKS FROM BACKEND ============
      // ✅ The backend now returns a personalized link per contact
      final receiverLinks =
          (emergencyResponse['receiverLinks'] as List?)
              ?.map((r) => ReceiverLink.fromJson(r))
              .toList() ??
          [];

      print('📱 Received ${receiverLinks.length} receiver links from backend');

      // ============ 4. SEND PERSONALIZED SMS TO CONTACTS ============
      final userName = await _storage.getUserName() ?? 'User';
      int smsSent = 0;
      int totalContacts = receiverLinks.length;

      for (final link in receiverLinks) {
        // ✅ Filter by customContacts if provided
        if (customContacts != null && customContacts.isNotEmpty) {
          final isSelected = customContacts.any((c) => c.id == link.contactId);
          if (!isSelected) continue;
        }

        try {
          final phoneNumber = _cleanPhone(link.contactPhone);

          final ok = await _smsService.sendPersonalizedEmergencyAlert(
            contactName: link.contactName,
            contactPhone: phoneNumber,
            userName: userName,
            webUrl: link.webUrl,
          );

          if (ok) smsSent++;
        } catch (e) {
          print('❌ SMS error for ${link.contactName}: $e');
        }
      }

      return SosResult(
        success: true,
        emergencyId: emergencyId,
        smsSentCount: smsSent,
        totalContacts: totalContacts,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return SosResult(success: false, error: e.toString());
    }
  }

  // ============ HELPER: Send SMS to one contact ============

  // ============ HELPER: Clean phone ============
  String _cleanPhone(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    if (!cleaned.startsWith('91')) {
      cleaned = '+91$cleaned';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }
}

/// ============================================================
/// Result object returned from trigger()
/// ============================================================
class SosResult {
  final bool success;
  final String? error;
  final String? emergencyId;
  final int smsSentCount;
  final int totalContacts;
  final double? latitude;
  final double? longitude;

  SosResult({
    required this.success,
    this.error,
    this.emergencyId,
    this.smsSentCount = 0,
    this.totalContacts = 0,
    this.latitude,
    this.longitude,
  });
}
