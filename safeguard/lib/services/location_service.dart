import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  Position? _currentPosition;
  bool _isTracking = false;
  final Geocoding _geocoding = Geocoding();

  Future<bool> checkPermissions() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  Future<Position> getCurrentLocation() async {
    final permission = await checkPermissions();
    if (!permission) {
      throw Exception('Location permission not granted');
    }

    _currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
    return _currentPosition!;
  }

  void startLocationUpdates(Function(Position) onUpdate) {
    if (_isTracking) return;

    _isTracking = true;

    // ✅ FIXED: Removed intervalDuration (not supported)
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

  // ✅ FIXED: Using placemarkFromCoordinates correctly
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      // ✅ FIXED: Use proper method with correct import
      final placemarks = await _geocoding.placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}';
      }
      return 'Unknown location';
    } catch (e) {
      print('Error getting address: $e');
      return 'Unknown location';
    }
  }
}
