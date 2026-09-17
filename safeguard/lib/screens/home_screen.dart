import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/location_provider.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../services/sms_service.dart';
import '../utils/app_colors.dart';
import 'emergency_mode_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late GoogleMapController _mapController;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupLocationTracking();
  }

  // ============ DATA ============
  void _loadData() {
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );
    emergencyProvider.loadContacts();
    emergencyProvider.loadHistory();
  }

  void _setupLocationTracking() {
    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    locationProvider.startTracking();
  }

  // ============ PHONE CLEANER ============
  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) cleaned = cleaned.substring(1);
    if (!cleaned.startsWith('91')) {
      cleaned = '+91$cleaned';
    } else if (!cleaned.startsWith('+')) {
      cleaned = '+$cleaned';
    }
    return cleaned;
  }

  // ============ BUILD ============
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final emergencyProvider = Provider.of<EmergencyProvider>(context);

    final position = locationProvider.currentPosition;
    final markers = position != null
        ? {
            Marker(
              markerId: const MarkerId('current_location'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
            ),
          }
        : <Marker>{};

    return Scaffold(
      backgroundColor: AppColors.background,
      // ❌ NO drawer
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // 1️⃣ HEADER
              _buildHeader(authProvider.user),

              const SizedBox(height: 20),

              // 2️⃣ STATUS CARD
              _buildSafetyStatusCard(emergencyProvider.isEmergencyActive),

              const SizedBox(height: 24),

              // 3️⃣ MAP
              _buildMapSection(position, markers),

              const SizedBox(height: 20),

              // 4️⃣ SOS BUTTON (Big bar)
              _buildSOSButton(),

              const SizedBox(height: 24),

              // 5️⃣ QUICK ACTIONS (moved BELOW map + SOS)
              _buildQuickActions(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ============ HEADER ============
  Widget _buildHeader(UserModel? user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Greeting + Name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good ${_getGreeting()},',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMedium,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user?.name ?? 'User',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Action buttons: SOS (small circle) + Notification + Profile
        Row(
          children: [
            // ✅ SMALL CIRCULAR SOS BUTTON
            GestureDetector(
              onTap: _showSOSDialog,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.dangerGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'SOS',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // ✅ NOTIFICATION ICON
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
              child: Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      boxShadow: AppColors.softShadow,
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: AppColors.textDark,
                      size: 22,
                    ),
                  ),
                  // Red badge
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.card, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // ✅ PROFILE AVATAR
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppColors.softShadow,
                ),
                child: Center(
                  child: Text(
                    (user?.name.isNotEmpty == true
                        ? user!.name[0].toUpperCase()
                        : 'U'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============ SAFETY STATUS CARD ============
  Widget _buildSafetyStatusCard(bool isEmergencyActive) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isEmergencyActive
            ? AppColors.dangerGradient
            : AppColors.tealGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: (isEmergencyActive ? AppColors.danger : AppColors.secondary)
                .withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isEmergencyActive
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEmergencyActive ? 'Emergency Active' : 'Safety Status',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            isEmergencyActive ? "You're in EMERGENCY MODE" : "You're safe!",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isEmergencyActive
                ? 'Your contacts have been notified with your live location.'
                : 'We are monitoring your safety in real-time. Stay aware of your surroundings.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  isEmergencyActive ? 'LIVE TRACKING ON' : '24/7 ACTIVE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ MAP ============
  Widget _buildMapSection(dynamic position, Set<Marker> markers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Location',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
            boxShadow: AppColors.softShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
            child: position != null
                ? GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(position.latitude, position.longitude),
                      zoom: 15,
                    ),
                    markers: markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
          ),
        ),
      ],
    );
  }

  // ============ SOS BUTTON (Big bar) ============
  Widget _buildSOSButton() {
    return Center(
      child: GestureDetector(
        onTap: _showSOSDialog,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: AppColors.dangerGradient,
            borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
            boxShadow: [
              BoxShadow(
                color: AppColors.danger.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to activate emergency',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ QUICK ACTIONS (Now BELOW map + SOS) ============
  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.people_alt_rounded,
          iconColor: AppColors.primary,
          title: 'Emergency Contacts',
          subtitle: 'Manage trusted contacts',
          onTap: () => Navigator.pushNamed(context, '/contacts'),
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.notifications_active_rounded,
          iconColor: AppColors.danger,
          title: 'Notifications',
          subtitle: 'Replies & emergency history',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.secondary,
          title: 'Share Live Location',
          subtitle: 'Send to emergency contacts',
          onTap: () {
            final location = Provider.of<LocationProvider>(
              context,
              listen: false,
            ).currentPosition;
            if (location != null) {
              _mapController.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(location.latitude, location.longitude),
                    zoom: 16,
                  ),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 10),
        _buildActionTile(
          icon: Icons.history_rounded,
          iconColor: AppColors.warning,
          title: 'Emergency History',
          subtitle: 'View past emergencies',
          onTap: () => _showHistory(context),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppColors.radiusMedium),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  // ============ BOTTOM NAV ============
  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home_rounded, 'Home', true, () {}),
          _buildNavItem(
            Icons.people_rounded,
            'Contacts',
            false,
            () => Navigator.pushNamed(context, '/contacts'),
          ),
          _buildNavItem(Icons.notifications_rounded, 'Alerts', false, () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          }),
          _buildNavItem(
            Icons.person_rounded,
            'Profile',
            false,
            () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isActive ? AppColors.primary : AppColors.textLight,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isActive ? AppColors.primary : AppColors.textLight,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  // ============ SOS DIALOG ============
  void _showSOSDialog() {
    print('🔴 SOS BUTTON PRESSED - Dialog opening...');
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );

    if (emergencyProvider.contacts.isEmpty) {
      emergencyProvider.loadContacts();
    }

    Map<String, bool> selectedContacts = {};
    for (var contact in emergencyProvider.contacts) {
      selectedContacts[contact.id] = true;
    }

    bool shareCamera = false;
    bool shareVideo = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusXLarge),
            ),
            title: Row(
              children: const [
                Icon(Icons.warning, color: AppColors.danger),
                SizedBox(width: 8),
                Text('Activate SOS?'),
              ],
            ),
            content: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select contacts to notify:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  if (emergencyProvider.contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No contacts added. Please add emergency contacts first.',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: emergencyProvider.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = emergencyProvider.contacts[index];
                          return CheckboxListTile(
                            value: selectedContacts[contact.id] ?? true,
                            onChanged: (value) {
                              setDialogState(() {
                                selectedContacts[contact.id] = value ?? false;
                              });
                            },
                            title: Text(contact.name),
                            subtitle: Text(contact.phone),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            activeColor: AppColors.primary,
                          );
                        },
                      ),
                    ),

                  const Divider(),
                  const SizedBox(height: 8),

                  // Camera toggle
                  Row(
                    children: [
                      const Icon(Icons.camera_alt, color: AppColors.primary),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Share Camera Images')),
                      Switch(
                        value: shareCamera,
                        onChanged: (v) => setDialogState(() => shareCamera = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Video toggle
                  Row(
                    children: [
                      const Icon(Icons.videocam, color: AppColors.secondary),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Share Live Video')),
                      Switch(
                        value: shareVideo,
                        onChanged: (v) => setDialogState(() => shareVideo = v),
                        activeColor: AppColors.secondary,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Selected count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSelectedCount(selectedContacts) > 0
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getSelectedCount(selectedContacts) > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                    child: Text(
                      '${_getSelectedCount(selectedContacts) > 0 ? "✅" : "⚠️"} '
                      '${_getSelectedCount(selectedContacts)} contacts selected',
                      style: TextStyle(
                        color: _getSelectedCount(selectedContacts) > 0
                            ? AppColors.success
                            : AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: _getSelectedCount(selectedContacts) == 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        _activateSOS(selectedContacts, shareCamera, shareVideo);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ACTIVATE SOS'),
              ),
            ],
          );
        },
      ),
    );
  }

  int _getSelectedCount(Map<String, bool> selectedContacts) {
    return selectedContacts.values.where((v) => v).length;
  }

  // ============ ACTIVATE SOS ============
  void _activateSOS(
    Map<String, bool> selectedContacts,
    bool shareCamera,
    bool shareVideo,
  ) async {
    print('🔴 ===== ACTIVATE SOS CALLED =====');
    print('📱 Selected contacts: ${selectedContacts.length}');

    final locationProvider = Provider.of<LocationProvider>(
      context,
      listen: false,
    );
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );
    final smsService = Provider.of<SmsService>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final user = authProvider.user;
    if (user == null) {
      _showSnackBar('User not logged in. Please login again.', isError: true);
      return;
    }

    final position = locationProvider.currentPosition;
    if (position == null) {
      _showSnackBar(
        'Unable to get your location. Please enable GPS.',
        isError: true,
      );
      return;
    }

    List<EmergencyContact> selectedContactList = [];
    for (var contact in emergencyProvider.contacts) {
      if (selectedContacts[contact.id] == true) {
        selectedContactList.add(contact);
      }
    }

    if (selectedContactList.isEmpty) {
      _showSnackBar('No contacts selected!', isError: true);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                SizedBox(height: 16),
                Text('Activating SOS...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Start emergency
      final success = await emergencyProvider.startEmergency(
        position.latitude,
        position.longitude,
      );

      if (!success) {
        Navigator.pop(context);
        _showSnackBar(
          emergencyProvider.error ?? 'Failed to start emergency',
          isError: true,
        );
        return;
      }

      final emergency = emergencyProvider.currentEmergency;
      if (emergency == null) {
        Navigator.pop(context);
        _showSnackBar('Emergency not found after creation', isError: true);
        return;
      }

      // 2. Generate web link
      String webUrl = '';
      try {
        final webResult = await emergencyProvider.generateWebStream(
          emergency.id,
        );
        if (webResult['success'] == true) {
          webUrl = webResult['webUrl'] ?? '';
        }
      } catch (e) {
        print('⚠️ Web link generation error: $e');
      }

      // 3. Send SMS
      int smsSent = 0;
      for (var contact in selectedContactList) {
        try {
          final phoneNumber = _cleanPhoneNumber(contact.phone);
          bool result;
          if (webUrl.isNotEmpty) {
            result = await smsService.sendEmergencyAlertWithWebLink(
              contactName: contact.name,
              contactPhone: phoneNumber,
              userName: user.name,
              latitude: position.latitude,
              longitude: position.longitude,
              emergencyId: emergency.id,
              webUrl: webUrl,
            );
          } else {
            result = await smsService.sendEmergencyAlert(
              contactName: contact.name,
              contactPhone: phoneNumber,
              userName: user.name,
              latitude: position.latitude,
              longitude: position.longitude,
              emergencyId: emergency.id,
            );
          }
          if (result) smsSent++;
        } catch (e) {
          print('❌ SMS error for ${contact.name}: $e');
        }
      }

      Navigator.pop(context);
      _showSnackBar(
        '✅ SOS Activated! SMS sent to $smsSent/${selectedContactList.length} contacts',
      );

      if (mounted) {
        Navigator.pushNamed(context, '/emergency');
      }
    } catch (e) {
      Navigator.pop(context);
      _showSnackBar('Error: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        ),
      ),
    );
  }

  // ============ HISTORY ============
  void _showHistory(BuildContext context) {
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );
    emergencyProvider.loadHistory();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency History',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: emergencyProvider.history.isEmpty
                  ? const Center(child: Text('No emergency history'))
                  : ListView.builder(
                      itemCount: emergencyProvider.history.length,
                      itemBuilder: (context, index) {
                        final emergency = emergencyProvider.history[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: emergency.status == 'resolved'
                                ? AppColors.success
                                : AppColors.warning,
                            child: Text(
                              emergency.status == 'resolved' ? '✓' : '!',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          title: Text(
                            'Emergency on ${_formatDate(emergency.startTime)}',
                          ),
                          subtitle: Text(
                            'Status: ${emergency.status} • ${_formatTime(emergency.startTime)}',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                          ),
                          onTap: () {},
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}
