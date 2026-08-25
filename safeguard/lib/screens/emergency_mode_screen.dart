import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../providers/emergency_provider.dart';
import '../providers/location_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sms_service.dart';

class EmergencyModeScreen extends StatefulWidget {
  const EmergencyModeScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

class _EmergencyModeScreenState extends State<EmergencyModeScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  String _locationUpdate = 'Updating...';
  bool _isCapturingImage = false;
  bool _isSendingSms = false;

  @override
  void initState() {
    super.initState();
    _setupEmergencyTracking();
  }

  void _setupEmergencyTracking() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );

    if (!locationProvider.isTracking) {
      locationProvider.startTracking();
    }

    locationProvider.addListener(() {
      final position = locationProvider.currentPosition;
      if (position != null && emergencyProvider.currentEmergency != null) {
        _updateLocation(position.latitude, position.longitude);
        _updateMarker(LatLng(position.latitude, position.longitude));

        emergencyProvider.updateEmergencyLocation(
          emergencyProvider.currentEmergency!.id,
          position.latitude,
          position.longitude,
        );
      }
    });
  }

  void _updateLocation(double lat, double lng) {
    setState(() {
      _locationUpdate =
          '📍 ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    });
  }

  void _updateMarker(LatLng position) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('emergency_location'),
          position: position,
          infoWindow: const InfoWindow(title: 'Your Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });
  }

  Future<void> _sendSmsToContacts() async {
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final smsService = Provider.of<SmsService>(context, listen: false);

    final emergency = emergencyProvider.currentEmergency;
    final user = authProvider.user;
    final position = locationProvider.currentPosition;

    if (emergency == null || user == null || position == null) return;

    setState(() => _isSendingSms = true);

    try {
      final contacts = emergencyProvider.contacts;
      int sentCount = 0;

      for (final contact in contacts) {
        final success = await smsService.sendEmergencyAlert(
          contactName: contact.name,
          contactPhone: contact.phone,
          userName: user.name,
          latitude: position.latitude,
          longitude: position.longitude,
          emergencyId: emergency.id,
        );

        if (success) sentCount++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ SMS sent to $sentCount/${contacts.length} contacts'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending SMS: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSendingSms = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emergencyProvider = Provider.of<EmergencyProvider>(context);
    final emergency = emergencyProvider.currentEmergency;
    final locationProvider = Provider.of<LocationProvider>(context);
    final position = locationProvider.currentPosition;

    if (emergency == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: Colors.red),
              const SizedBox(height: 16),
              const Text('No active emergency found'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('GO BACK'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.redAccent],
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🚨 EMERGENCY MODE ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Started: ${_formatTime(emergency.startTime)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.location_on, color: Colors.white),
                ],
              ),
            ),

            Expanded(
              flex: 2,
              child: position != null
                  ? GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(position.latitude, position.longitude),
                        zoom: 16,
                      ),
                      markers: _markers,
                      myLocationEnabled: true,
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey.shade50,
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Location Sharing: LIVE',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Text(
                        _locationUpdate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.people, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'Alert sent to: ${emergency.notifiedContacts.length} contacts',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const Spacer(),
                      if (_isSendingSms)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isCapturingImage ? null : _captureImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isCapturingImage
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.camera_alt),
                      label: const Text('CAPTURE IMAGE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSendingSms ? null : _sendSmsToContacts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      icon: _isSendingSms
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sms),
                      label: const Text('SEND SMS'),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _stopEmergency(context, emergencyProvider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  '⬛ STOP EMERGENCY',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureImage() async {
    setState(() => _isCapturingImage = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📸 Image captured successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error capturing image: $e')));
    } finally {
      setState(() => _isCapturingImage = false);
    }
  }

  void _stopEmergency(BuildContext context, EmergencyProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Stop Emergency Mode?'),
        content: const Text('Are you sure you are safe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text("YES, I'M SAFE"),
          ),
        ],
      ),
    );

    if (confirmed == true && provider.currentEmergency != null) {
      await provider.stopEmergency(provider.currentEmergency!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
