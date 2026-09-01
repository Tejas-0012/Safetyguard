import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/emergency_model.dart';
import '../models/contact_model.dart';
import '../models/user_model.dart';

class EmergencyProvider extends ChangeNotifier {
  final ApiService _apiService;
  Emergency? _currentEmergency;
  List<Emergency> _history = [];
  List<EmergencyContact> _contacts = [];
  bool _isLoading = false;
  String? _error;

  EmergencyProvider(this._apiService);

  Emergency? get currentEmergency => _currentEmergency;
  List<Emergency> get history => _history;
  List<EmergencyContact> get contacts => _contacts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmergencyActive => _currentEmergency?.status == 'active';

  Future<void> loadContacts() async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.getContacts();
      if (response['success'] == true) {
        _contacts = (response['contacts'] as List)
            .map((c) => EmergencyContact.fromJson(c))
            .toList();
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addContact(
    String name,
    String phone, {
    String? email,
    String? relation,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.addContact({
        'name': name,
        'phone': phone,
        'email': email,
        'relation': relation,
      });

      if (response['success'] == true) {
        await loadContacts();
      } else {
        _error = response['message'] ?? 'Failed to add contact';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateContact(
    String id,
    String name,
    String phone, {
    String? email,
    String? relation,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.updateContact(id, {
        'name': name,
        'phone': phone,
        'email': email,
        'relation': relation,
      });

      if (response['success'] == true) {
        await loadContacts();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to update contact';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.deleteContact(id);
      if (response['success'] == true) {
        await loadContacts();
      } else {
        _error = response['message'] ?? 'Failed to delete contact';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> startEmergency(double latitude, double longitude) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _apiService.startEmergency({
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response['success'] == true) {
        _currentEmergency = Emergency.fromJson(response['emergency']);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response['message'] ?? 'Failed to start emergency';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> updateEmergencyLocation(
    String emergencyId,
    double latitude,
    double longitude,
  ) async {
    try {
      final response = await _apiService.updateEmergencyLocation(emergencyId, {
        'latitude': latitude,
        'longitude': longitude,
      });

      if (response['success'] == true && _currentEmergency != null) {
        _currentEmergency!.currentLocation = LocationPoint.fromJson(
          response['location'],
        );
        notifyListeners();
      }
    } catch (e) {
      print('Error updating emergency location: $e');
    }
  }

  Future<void> stopEmergency(String emergencyId) async {
    try {
      _isLoading = true;
      notifyListeners();

      final response = await _apiService.stopEmergency(emergencyId);
      if (response['success'] == true) {
        _currentEmergency = null;
        await loadHistory();
      } else {
        _error = response['message'] ?? 'Failed to stop emergency';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    try {
      final response = await _apiService.getEmergencyHistory();
      if (response['success'] == true) {
        _history = (response['emergencies'] as List)
            .map((e) => Emergency.fromJson(e))
            .toList();
        _error = null;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  Future<void> refreshEmergencyStatus(String emergencyId) async {
    try {
      final response = await _apiService.getEmergencyStatus(emergencyId);
      if (response['success'] == true) {
        final emergency = Emergency.fromJson(response['emergency']);
        if (emergency.status != 'active') {
          _currentEmergency = null;
        } else {
          _currentEmergency = emergency;
        }
        notifyListeners();
      }
    } catch (e) {
      print('Error refreshing emergency status: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
