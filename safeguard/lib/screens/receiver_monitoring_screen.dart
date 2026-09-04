import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/emergency_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sms_service.dart';
import '../models/emergency_model.dart';
import '../models/user_model.dart';

class ReceiverMonitoringScreen extends StatefulWidget {
  final String emergencyId;

  const ReceiverMonitoringScreen({super.key, required this.emergencyId});

  @override
  State<ReceiverMonitoringScreen> createState() =>
      _ReceiverMonitoringScreenState();
}

class _ReceiverMonitoringScreenState extends State<ReceiverMonitoringScreen> {
  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  final TextEditingController _replyController = TextEditingController();
  bool _isLoading = true;
  Emergency? _emergency;
  List<ReceiverReply> _replies = [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyDetails();
    _setupSmsListener();
  }

  Future<void> _loadEmergencyDetails() async {
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );
    await emergencyProvider.refreshEmergencyStatus(widget.emergencyId);

    final emergency = emergencyProvider.currentEmergency;
    if (emergency != null) {
      setState(() {
        _emergency = emergency;
        _isLoading = false;
        _replies = emergency.receiverReplies ?? [];
      });
    }
    setState(() => _isLoading = false);
  }

  void _setupSmsListener() {
    final smsService = SmsService();
    smsService.listenForReplies((sender, message) {
      setState(() {
        _replies.add(
          ReceiverReply(
            contactId: '',
            contactName: sender,
            message: message,
            repliedAt: DateTime.now(),
          ),
        );
      });
      _showSnackBar('📩 Reply from $sender: $message');
    });
  }

  Future<void> _sendReply(String message) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );

    try {
      await emergencyProvider.replyToEmergency(widget.emergencyId, message);

      setState(() {
        _replies.add(
          ReceiverReply(
            contactId: '',
            contactName: authProvider.user?.name ?? 'You',
            message: message,
            repliedAt: DateTime.now(),
          ),
        );
      });

      _replyController.clear();
      _showSnackBar('✅ Reply sent: "$message"');
    } catch (e) {
      _showSnackBar('❌ Failed to send reply: $e');
    }
  }

  Future<void> _generateWebLink() async {
    final emergencyProvider = Provider.of<EmergencyProvider>(
      context,
      listen: false,
    );

    try {
      final result = await emergencyProvider.generateWebStream(
        widget.emergencyId,
      );
      if (result['success'] == true) {
        final webUrl = result['webUrl'];
        _showSnackBar('🌐 Link generated! Share it with others.');
        await _shareLink(webUrl);
      }
    } catch (e) {
      _showSnackBar('❌ Failed to generate link: $e');
    }
  }

  Future<void> _shareLink(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_emergency == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Emergency Details')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 60, color: Colors.red),
              SizedBox(height: 16),
              Text('No active emergency found'),
            ],
          ),
        ),
      );
    }

    // ✅ Get sender info from emergency.userId (now UserModel)
    final sender = _emergency?.userId;
    final senderName = sender?.name ?? 'Unknown';
    final senderPhone = sender?.phone ?? 'No phone';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Monitoring'),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _generateWebLink,
            tooltip: 'Share web link',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEmergencyDetails,
          ),
        ],
      ),
      body: Column(
        children: [
          // Sender Info
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.red.shade50,
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Text(
                    senderName.isNotEmpty ? senderName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '📱 $senderPhone',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _emergency?.status == 'active'
                        ? Colors.red
                        : Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _emergency?.status?.toUpperCase() ?? 'ACTIVE',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Map
          Expanded(
            flex: 2,
            child: _emergency?.currentLocation != null
                ? GoogleMap(
                    onMapCreated: (controller) => _mapController = controller,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        _emergency!.currentLocation!.latitude,
                        _emergency!.currentLocation!.longitude,
                      ),
                      zoom: 15,
                    ),
                    markers: _buildMarkers(),
                    myLocationEnabled: true,
                  )
                : const Center(child: Text('No location data')),
          ),

          // Images
          if (_emergency?.cameraImages?.isNotEmpty == true)
            Container(
              height: 100,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _emergency!.cameraImages!.length,
                itemBuilder: (context, index) {
                  final image = _emergency!.cameraImages![index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(image.url),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),

          // Replies
          Container(
            height: 120,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    const Text(
                      'Replies',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_replies.length} replies',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _replies.isEmpty
                      ? const Center(
                          child: Text(
                            'No replies yet. Send "I\'m coming" to respond.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _replies.length,
                          itemBuilder: (context, index) {
                            final reply = _replies[index];
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                            );
                            final isYou =
                                reply.contactName == 'You' ||
                                reply.contactName ==
                                    (authProvider.user?.name ?? '');
                            return Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isYou
                                    ? Colors.green.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isYou
                                      ? Colors.green.shade200
                                      : Colors.blue.shade200,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        reply.contactName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatTime(reply.repliedAt),
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    reply.message,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Reply Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Type "I\'m coming"...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _sendReply(value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    if (_replyController.text.isNotEmpty) {
                      _sendReply(_replyController.text);
                    }
                  },
                  icon: const Icon(Icons.send, color: Colors.blue),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    if (_emergency?.currentLocation == null) return {};
    return {
      Marker(
        markerId: const MarkerId('sender_location'),
        position: LatLng(
          _emergency!.currentLocation!.latitude,
          _emergency!.currentLocation!.longitude,
        ),
        infoWindow: const InfoWindow(title: 'Sender\'s Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    };
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message.contains('✅') ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }
}
