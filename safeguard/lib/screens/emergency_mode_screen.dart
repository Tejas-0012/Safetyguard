import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../providers/emergency_provider.dart';
import '../providers/location_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sms_service.dart';
import '../utils/app_colors.dart';
import '../models/emergency_model.dart';
import 'emergency_replies_screen.dart';

class EmergencyModeScreen extends StatefulWidget {
  const EmergencyModeScreen({super.key});

  @override
  State<EmergencyModeScreen> createState() => _EmergencyModeScreenState();
}

class _EmergencyModeScreenState extends State<EmergencyModeScreen> {
  Timer? _refreshTimer;
  List<ReceiverLink> _receiverLinks = [];
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};
  String _locationUpdate = 'Updating...';
  bool _isCapturingImage = false;
  bool _isSendingSms = false;
  BitmapDescriptor? _personIcon;

  LocationProvider? _locationProvider;
  EmergencyProvider? _emergencyProvider;

  @override
  void initState() {
    super.initState();
    _loadPersonIcon();
    _setupEmergencyTracking();

    // ✅ Poll backend for receiver locations every 5 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      _refreshReceiverLocations();
    });
  }

  Future<void> _loadPersonIcon() async {
    // ⚠️ Temporarily disable custom PNG (bad image caused marker crash)
    // Use Google's built-in blue marker instead
    if (mounted) {
      setState(() {
        _personIcon = BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueAzure,
        );
      });
      print('✅ Using default blue marker (custom PNG disabled)');
    }
  }

  Future<void> _refreshReceiverLocations() async {
    final provider = Provider.of<EmergencyProvider>(context, listen: false);
    final emergencyId = provider.currentEmergency?.id;
    if (emergencyId == null) {
      print('❌ No emergencyId');
      return;
    }

    try {
      final response = await provider.getEmergencyDetails(emergencyId);
      print('🔄 getEmergencyDetails success: ${response['success']}');

      if (response['success'] == true && response['emergency'] != null) {
        final em = Emergency.fromJson(response['emergency']);
        print('📱 Receiver links received: ${em.receiverLinks.length}');

        for (final link in em.receiverLinks) {
          print(
            '   - ${link.contactName}: '
            'linkOpened=${link.linkOpened}, '
            'hasLocation=${link.hasLocation}, '
            'lat=${link.latitude}, '
            'lng=${link.longitude}, '
            'isSharing=${link.isSharingLocation}',
          );
        }

        if (mounted) {
          setState(() {
            _receiverLinks = em.receiverLinks;
          });
          // ✅ Rebuild markers after updating receiver links
          final victimPos = _locationProvider?.currentPosition;
          if (victimPos != null) {
            _buildAllMarkers(LatLng(victimPos.latitude, victimPos.longitude));
          }
        }
      } else {
        print('❌ getEmergencyDetails failed: ${response['message']}');
      }
    } catch (e) {
      print('❌ Failed to refresh receiver locations: $e');
    }
  }

  Future<BitmapDescriptor> _getPersonMarkerIcon() async {
    return await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icon/person_marker.png',
    );
  }

  void _onLocationChanged() {
    final position = _locationProvider?.currentPosition;
    if (position != null && _emergencyProvider?.currentEmergency != null) {
      _updateLocation(position.latitude, position.longitude);
      _buildAllMarkers(LatLng(position.latitude, position.longitude));

      _emergencyProvider!.updateEmergencyLocation(
        _emergencyProvider!.currentEmergency!.id,
        position.latitude,
        position.longitude,
      );
    }
  }

  Widget _buildReceiverStatusCard() {
    final victimPos = _locationProvider?.currentPosition;
    if (victimPos == null) return const SizedBox.shrink();

    // Only show if at least one receiver has opened the link
    final activeReceivers = _receiverLinks.where((l) => l.linkOpened).toList();
    if (activeReceivers.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.help_center, color: AppColors.success, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Help is on the way!',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...activeReceivers.map((link) {
            String distanceText = 'Location pending';
            double? etaMinutes;

            if (link.hasLocation) {
              final distance = Geolocator.distanceBetween(
                victimPos.latitude,
                victimPos.longitude,
                link.latitude!,
                link.longitude!,
              );
              distanceText = _formatDistance(distance);
              // Assume average speed of 40 km/h
              etaMinutes = (distance / 1000) / 40 * 60;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 18,
                    color: link.hasLocation
                        ? AppColors.primary
                        : AppColors.textLight,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      link.contactName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    link.hasLocation && etaMinutes != null
                        ? '$distanceText • ~${etaMinutes.toStringAsFixed(0)} min'
                        : 'Link opened',
                    style: TextStyle(
                      fontSize: 12,
                      color: link.hasLocation
                          ? AppColors.success
                          : AppColors.textLight,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _setupEmergencyTracking() {
    _locationProvider = Provider.of<LocationProvider>(context, listen: false);
    _emergencyProvider = Provider.of<EmergencyProvider>(context, listen: false);

    if (!_locationProvider!.isTracking) {
      _locationProvider!.startTracking();
    }

    _locationProvider!.addListener(_onLocationChanged);
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationProvider?.removeListener(_onLocationChanged);
    super.dispose();
  }

  void _updateLocation(double lat, double lng) {
    if (!mounted) return;
    setState(() {
      _locationUpdate = '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
    });
  }

  void _buildAllMarkers(LatLng victimPos) {
    final Set<Marker> newMarkers = {};

    // ✅ Victim marker (red)
    newMarkers.add(
      Marker(
        markerId: const MarkerId('victim'),
        position: victimPos,
        infoWindow: const InfoWindow(title: 'You'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    // ✅ Receiver markers (blue person icons + name)
    for (final link in _receiverLinks) {
      if (!link.hasLocation) continue;

      final position = LatLng(link.latitude!, link.longitude!);
      final distanceMeters = Geolocator.distanceBetween(
        victimPos.latitude,
        victimPos.longitude,
        position.latitude,
        position.longitude,
      );

      newMarkers.add(
        Marker(
          markerId: MarkerId('receiver_${link.token}'),
          position: position,
          infoWindow: InfoWindow(
            title: link.contactName,
            snippet: '${_formatDistance(distanceMeters)} away',
          ),
          // ✅ Use built-in info icon (person) with blue hue
          icon:
              _personIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers = newMarkers;
      });
    }
  }

  // ============ SEND SMS ============
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
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMedium),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending SMS: ${e.toString()}'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
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
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 60,
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'No active emergency found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                  ),
                ),
                child: const Text('GO BACK'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ============ EMERGENCY HEADER with BACK button ============
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
              decoration: BoxDecoration(
                gradient: AppColors.dangerGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      // ✅ BACK BUTTON
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        tooltip: 'Go Back',
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY MODE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Active • Live Tracking On',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _formatTime(emergency.startTime),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ============ MAP ============
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
                  boxShadow: AppColors.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
                  child: position != null
                      ? GoogleMap(
                          onMapCreated: (controller) =>
                              _mapController = controller,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              position.latitude,
                              position.longitude,
                            ),
                            zoom: 16,
                          ),
                          markers: _markers,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                        )
                      : const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                ),
              ),
            ),
            // ✅ Receiver status card (below map)
            _buildReceiverStatusCard(),
            const SizedBox(height: 8),
            // ============ STATUS CARD ============
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(AppColors.radiusLarge),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Location Sharing: LIVE',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      const Spacer(),
                      if (_isSendingSms)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _locationUpdate,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMedium,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.people_alt_rounded,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Alert sent to ${emergency.notifiedContacts.length} contacts',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============ ACTION BUTTONS ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'CAPTURE',
                      color: AppColors.primary,
                      isLoading: _isCapturingImage,
                      onTap: _isCapturingImage ? null : _captureImage,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.sms_rounded,
                      label: 'SEND SMS',
                      color: AppColors.secondary,
                      isLoading: _isSendingSms,
                      onTap: _isSendingSms ? null : _sendSmsToContacts,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ============ VIEW REPLIES ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EmergencyRepliesScreen(
                          emergencyId: emergency.id,
                          emergencyTitle: 'Emergency',
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppColors.radiusLarge,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 20),
                  label: const Text(
                    'VIEW REPLIES FROM CONTACTS',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ============ STOP EMERGENCY ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _stopEmergency(context, emergencyProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppColors.radiusLarge,
                      ),
                    ),
                    elevation: 3,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_rounded, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'STOP EMERGENCY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ============ ACTION BUTTON WIDGET ============
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required bool isLoading,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        ),
      ),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 20),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  // ============ CAPTURE IMAGE ============
  Future<void> _captureImage() async {
    setState(() => _isCapturingImage = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.camera);

      if (image != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('📸 Image captured successfully!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing image: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      setState(() => _isCapturingImage = false);
    }
  }

  // ============ STOP EMERGENCY ============
  void _stopEmergency(BuildContext context, EmergencyProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        ),
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
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMedium),
              ),
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
