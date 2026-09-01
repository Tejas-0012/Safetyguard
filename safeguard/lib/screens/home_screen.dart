import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/auth_provider.dart';
import '../providers/emergency_provider.dart';
import '../providers/location_provider.dart';
import '../models/user_model.dart';
import '../models/contact_model.dart';
import '../services/sms_service.dart';
import 'emergency_mode_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final locationProvider = Provider.of<LocationProvider>(context);
    final emergencyProvider = Provider.of<EmergencyProvider>(context);

    final position = locationProvider.currentPosition;
    // Build markers directly instead of calling setState() during build()
    // (which throws "setState() called during build").
    final markers = position != null
        ? {
            Marker(
              markerId: const MarkerId('current_location'),
              position: LatLng(position.latitude, position.longitude),
              infoWindow: const InfoWindow(title: 'Your Location'),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            ),
          }
        : <Marker>{};

    return Scaffold(
      drawer: _buildDrawer(context),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(authProvider.user),
            _buildSafetyStatus(emergencyProvider.isEmergencyActive),
            Expanded(
              flex: 3,
              child: position != null
                  ? GoogleMap(
                      onMapCreated: (controller) => _mapController = controller,
                      initialCameraPosition: CameraPosition(
                        target: LatLng(position.latitude, position.longitude),
                        zoom: 15,
                      ),
                      markers: markers,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                      zoomControlsEnabled: true,
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
            _buildSOSButton(),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(UserModel? user) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Builder(
            builder: (context) => IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.menu, color: Color(0xFF1A237E)),
            ),
          ),
          Expanded(
            child: Text(
              'SafeGuard',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A237E),
              ),
            ),
          ),
          CircleAvatar(
            backgroundColor: const Color(0xFF1A237E),
            child: Text(
              (user?.name.isNotEmpty == true
                  ? user!.name.substring(0, 1).toUpperCase()
                  : 'U'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyStatus(bool isEmergencyActive) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isEmergencyActive
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEmergencyActive
              ? Colors.red.withOpacity(0.3)
              : Colors.green.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // ✅ Check this - make sure it's a single Widget, not a list
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isEmergencyActive ? Colors.red : Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEmergencyActive
                  ? '⚠️ EMERGENCY MODE ACTIVE'
                  : 'You are Safe • Monitoring Active',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isEmergencyActive
                    ? Colors.red.shade800
                    : Colors.green.shade800,
              ),
            ),
          ),
          Icon(
            isEmergencyActive ? Icons.warning : Icons.check_circle,
            color: isEmergencyActive ? Colors.red : Colors.green,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: GestureDetector(
          onTap: _showSOSDialog,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: const RadialGradient(
                colors: [Colors.red, Colors.redAccent],
                center: Alignment.center,
                radius: 0.8,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.warning_rounded, color: Colors.white, size: 40),
                SizedBox(height: 4),
                Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(
            icon: Icons.people,
            label: 'Contacts',
            onTap: () => Navigator.pushNamed(context, '/contacts'),
          ),
          _buildNavItem(
            icon: Icons.location_on,
            label: 'Location',
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
          _buildNavItem(
            icon: Icons.person,
            label: 'Profile',
            onTap: () => Navigator.pushNamed(context, '/profile'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF1A237E)),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white,
                    child: Text(
                      (user?.name.isNotEmpty == true
                          ? user!.name.substring(0, 1).toUpperCase()
                          : 'U'),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    user?.phone ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(
                    icon: Icons.home,
                    title: 'Home',
                    onTap: () => Navigator.pop(context),
                  ),
                  _buildDrawerItem(
                    icon: Icons.people,
                    title: 'Emergency Contacts',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/contacts');
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.history,
                    title: 'Emergency History',
                    onTap: () {
                      Navigator.pop(context);
                      _showHistory(context);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person,
                    title: 'Profile',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/profile');
                    },
                  ),
                  const Divider(),
                  _buildDrawerItem(
                    icon: Icons.logout,
                    title: 'Logout',
                    onTap: () => _logout(context, authProvider),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFF1A237E)),
      title: Text(title, style: TextStyle(color: color)),
      onTap: onTap,
    );
  }

  // ============ SOS DIALOG WITH CONTACT CHECKLIST ============

  void _showSOSDialog() {
    print('🔴 SOS BUTTON PRESSED - Dialog opening...');
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );

    // Load contacts if empty
    if (emergencyProvider.contacts.isEmpty) {
      emergencyProvider.loadContacts();
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          print('📱 SOS Dialog is building...');
          // ✅ Initialize selected contacts (all selected by default)
          Map<String, bool> selectedContacts = {};
          for (var contact in emergencyProvider.contacts) {
            selectedContacts[contact.id] = true;
          }

          // ✅ Toggle states
          bool shareCamera = false;
          bool shareVideo = false;

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.warning, color: Colors.red),
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

                  // ✅ Contact Checklist
                  if (emergencyProvider.contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No contacts added. Please add emergency contacts first.',
                        style: TextStyle(color: Colors.grey),
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
                              setState(() {
                                selectedContacts[contact.id] = value ?? false;
                              });
                            },
                            title: Text(contact.name),
                            subtitle: Text(contact.phone),
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                          );
                        },
                      ),
                    ),

                  const Divider(),
                  const SizedBox(height: 8),

                  // ✅ Camera Toggle
                  Row(
                    children: [
                      const Icon(Icons.camera_alt, color: Colors.blue),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Share Camera Images')),
                      Switch(
                        value: shareCamera,
                        onChanged: (value) {
                          setState(() {
                            shareCamera = value;
                          });
                        },
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // ✅ Video Toggle
                  Row(
                    children: [
                      const Icon(Icons.videocam, color: Colors.purple),
                      const SizedBox(width: 12),
                      const Expanded(child: Text('Share Live Video')),
                      Switch(
                        value: shareVideo,
                        onChanged: (value) {
                          setState(() {
                            shareVideo = value;
                          });
                        },
                        activeColor: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // ✅ Selected contacts count - FIXED
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getSelectedCount(selectedContacts) > 0
                          ? Colors.green.withOpacity(0.1)
                          : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getSelectedCount(selectedContacts) > 0
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    child: Text(
                      '${_getSelectedCount(selectedContacts) > 0 ? "✅" : "⚠️"} ${_getSelectedCount(selectedContacts)} contacts selected',
                      style: TextStyle(
                        color: _getSelectedCount(selectedContacts) > 0
                            ? Colors.green
                            : Colors.red,
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
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('ACTIVATE SOS'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ✅ Helper method to count selected contacts
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
    print('📱 SmsService obtained: ${smsService != null}');
    final position = locationProvider.currentPosition;

    if (position == null) {
      print('❌ Position is NULL - GPS not available');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get your location. Please enable GPS.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    print('📍 Position: ${position.latitude}, ${position.longitude}');
    // Get selected contact details
    List<EmergencyContact> selectedContactList = [];
    for (var contact in emergencyProvider.contacts) {
      if (selectedContacts[contact.id] == true) {
        selectedContactList.add(contact);
      }
    }

    if (selectedContactList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contacts selected!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ✅ Show loading
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
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Activating SOS...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // 1. Start emergency on backend
      final success = await emergencyProvider.startEmergency(
        position.latitude,
        position.longitude,
      );

      if (!success) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              emergencyProvider.error ?? 'Failed to start emergency',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 2. Send SMS to selected contacts (Telephony)
      int smsSent = 0;
      for (var contact in selectedContactList) {
        try {
          final result = await smsService.sendSms(
            phoneNumber: contact.phone,
            message: 'Hi, its EMERGENCY! Please check the SafeGuard app for my live location.',
          );
          if (result) {
            smsSent++;
            print('✅ SMS sent to ${contact.name} (${contact.phone})');
          } else {
            print('❌ SMS failed to ${contact.name}');
          }
        } catch (e) {
          print('❌ SMS error for ${contact.name}: $e');
        }
      }

      // 3. Close loading dialog
      Navigator.pop(context);

      // 4. Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ SOS Activated! SMS sent to $smsSent/${selectedContactList.length} contacts',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // 5. Navigate to Emergency Mode
      if (mounted) {
        Navigator.pushNamed(context, '/emergency');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ SOS activation error: $e');
    }
  }

  // ============ OTHER METHODS ============

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
                                ? Colors.green
                                : Colors.orange,
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
                          onTap: () {
                            // Show emergency details
                          },
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
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _logout(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('LOGOUT'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await authProvider.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }
}
