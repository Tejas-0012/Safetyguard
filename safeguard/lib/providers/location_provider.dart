import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/storage_service.dart';

class LocationProvider extends ChangeNotifier {
  final LocationService _locationService;
  final StorageService? _storage;
  Position? _currentPosition;
  bool _isLoading = false;
  bool _isTracking = false;
  String? _error;

  LocationProvider(this._locationService, {StorageService? storage})
    : _storage = storage {
    _initialize();
  }

  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  bool get isTracking => _isTracking;
  String? get error => _error;

  Future<void> _initialize() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await getCurrentLocation();
  }

  Future<void> getCurrentLocation() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final position = await _locationService.getCurrentLocation();
      _currentPosition = position;
      _isLoading = false;
      notifyListeners();

      // ✅ Save immediately after getting location
      if (_storage != null) {
        await _storage!.saveLastLocation(position.latitude, position.longitude);
        print(
          '💾 Saved initial location: ${position.latitude}, ${position.longitude}',
        );
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('Error getting location: $e');
    }
  }

  void startTracking() {
    if (_isTracking) return;

    try {
      _isTracking = true;
      notifyListeners();

      _locationService.startLocationUpdates((position) {
        _currentPosition = position;
        notifyListeners();

        // ✅ Save to SharedPreferences on every update
        if (_storage != null) {
          _storage!.saveLastLocation(position.latitude, position.longitude);
        }
      });
    } catch (e) {
      _error = e.toString();
      _isTracking = false;
      notifyListeners();
      print('Error starting tracking: $e');
    }
  }

  void stopTracking() {
    _locationService.stopLocationUpdates();
    _isTracking = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
