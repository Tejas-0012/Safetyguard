import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/emergency_provider.dart';

class EmergencyMonitoringScreen extends StatefulWidget {
  const EmergencyMonitoringScreen({Key? key}) : super(key: key);

  @override
  State<EmergencyMonitoringScreen> createState() =>
      _EmergencyMonitoringScreenState();
}

class _EmergencyMonitoringScreenState extends State<EmergencyMonitoringScreen> {
  late GoogleMapController _mapController;
  Set<Marker> _markers = {};

  @override
  Widget build(BuildContext context) {
    final emergencyProvider = Provider.of<EmergencyProvider>(context);
    final emergency = emergencyProvider.currentEmergency;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Monitoring'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              if (emergency != null) {
                emergencyProvider.refreshEmergencyStatus(emergency.id);
              }
            },
          ),
        ],
      ),
      body: emergency == null
          ? const Center(child: Text('No active emergency'))
          : Column(
              children: [
                // Emergency Info
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.red.shade50,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text(
                            'EMERGENCY ACTIVE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Started: ${_formatTime(emergency.startTime)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Notified: ${emergency.notifiedContacts.length} contacts',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Map
                Expanded(
                  flex: 2,
                  child: emergency.currentLocation != null
                      ? GoogleMap(
                          onMapCreated: (controller) =>
                              _mapController = controller,
                          initialCameraPosition: CameraPosition(
                            target: LatLng(
                              emergency.currentLocation!.latitude,
                              emergency.currentLocation!.longitude,
                            ),
                            zoom: 15,
                          ),
                          markers: _markers,
                        )
                      : const Center(child: CircularProgressIndicator()),
                ),

                // Location updates
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Live Location Tracking',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          const Text(
                            '● LIVE',
                            style: TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (emergency.currentLocation != null)
                        Text(
                          '📍 ${emergency.currentLocation!.latitude.toStringAsFixed(6)}, '
                          '${emergency.currentLocation!.longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Navigate to location
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('NAVIGATE'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Call user
                          },
                          icon: const Icon(Icons.call),
                          label: const Text('CALL'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
