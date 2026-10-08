import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/contact_model.dart';
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

      // ============ 3. GENERATE WEB LINK ============
      String webUrl = '';
      try {
        final webResult = await _apiService.generateWebStream(emergencyId);
        if (webResult['success'] == true) {
          webUrl = webResult['webUrl'] ?? '';
        }
      } catch (_) {
        // Continue without web link
      }

      // ============ 4. SEND SMS TO CONTACTS ============
      final userName = await _storage.getUserName() ?? 'User';
      int smsSent = 0;
      int totalContacts = 0;

      if (customContacts != null && customContacts.isNotEmpty) {
        totalContacts = customContacts.length;
        for (final contact in customContacts) {
          final ok = await _sendSmsToContact(
            contact: contact,
            userName: userName,
            latitude: position.latitude,
            longitude: position.longitude,
            emergencyId: emergencyId,
            webUrl: webUrl,
          );
          if (ok) smsSent++;
        }
      } else {
        // Fetch contacts from backend
        final contactsResponse = await _apiService.getContacts();
        if (contactsResponse['success'] == true) {
          final contacts = (contactsResponse['contacts'] as List)
              .map((c) => EmergencyContact.fromJson(c))
              .toList();
          totalContacts = contacts.length;

          for (final contact in contacts) {
            final ok = await _sendSmsToContact(
              contact: contact,
              userName: userName,
              latitude: position.latitude,
              longitude: position.longitude,
              emergencyId: emergencyId,
              webUrl: webUrl,
            );
            if (ok) smsSent++;
          }
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
  Future<bool> _sendSmsToContact({
    required EmergencyContact contact,
    required String userName,
    required double latitude,
    required double longitude,
    required String emergencyId,
    required String webUrl,
  }) async {
    try {
      final phone = _cleanPhone(contact.phone);
      if (webUrl.isNotEmpty) {
        return await _smsService.sendEmergencyAlertWithWebLink(
          contactName: contact.name,
          contactPhone: phone,
          userName: userName,
          latitude: latitude,
          longitude: longitude,
          emergencyId: emergencyId,
          webUrl: webUrl,
        );
      } else {
        return await _smsService.sendEmergencyAlert(
          contactName: contact.name,
          contactPhone: phone,
          userName: userName,
          latitude: latitude,
          longitude: longitude,
          emergencyId: emergencyId,
        );
      }
    } catch (_) {
      return false;
    }
  }

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
