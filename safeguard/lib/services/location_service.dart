import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Position? _currentPosition;
  bool _isTracking = false;

  Future<bool> checkPermissions() async {
    try {
      final status = await Permission.location.request();
      return status.isGranted;
    } catch (e) {
      return true; // Web fallback
    }
  }

  Future<Position> getCurrentLocation() async {
    try {
      final permission = await checkPermissions();
      if (!permission) {
        return _getDefaultPosition();
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      return _currentPosition!;
    } catch (e) {
      return _getDefaultPosition();
    }
  }

  Position _getDefaultPosition() {
    // ✅ FIXED: All required parameters included
    return Position(
      latitude: 28.6139,
      longitude: 77.2090,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0, // ✅ Added
      heading: 0.0, // ✅ Added
      headingAccuracy: 0.0, // ✅ Added
      speed: 0.0,
      speedAccuracy: 0.0,
    );
  }

  void startLocationUpdates(Function(Position) onUpdate) {
    if (_isTracking) return;
    _isTracking = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (position) {
        _currentPosition = position;
        onUpdate(position);
      },
      onError: (error) {
        print('Location error: $error');
        _isTracking = false;
      },
    );
  }

  void stopLocationUpdates() {
    _isTracking = false;
  }

  Future<double> calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) async {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    return '📍 ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
  }
}
