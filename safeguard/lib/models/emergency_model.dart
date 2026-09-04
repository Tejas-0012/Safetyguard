import 'user_model.dart';

// ============ LOCATION POINT ============
class LocationPoint {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime timestamp;

  LocationPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  factory LocationPoint.fromJson(Map<String, dynamic> json) {
    return LocationPoint(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      accuracy: json['accuracy']?.toDouble(),
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

// ============ EMERGENCY IMAGE ============
// ✅ MOVED UP - Defined BEFORE Emergency class uses it
class EmergencyImage {
  final String url;
  final DateTime capturedAt;

  EmergencyImage({required this.url, required this.capturedAt});

  factory EmergencyImage.fromJson(Map<String, dynamic> json) {
    return EmergencyImage(
      url: json['url'] ?? '',
      capturedAt: json['capturedAt'] != null
          ? DateTime.parse(json['capturedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'capturedAt': capturedAt.toIso8601String()};
  }
}

// ============ RECEIVER REPLY ============
// ✅ MOVED UP - Defined BEFORE Emergency class uses it
class ReceiverReply {
  final String id;
  final String contactId;
  final String contactName;
  final String message;
  final DateTime repliedAt;

  ReceiverReply({
    this.id = '',
    required this.contactId,
    required this.contactName,
    required this.message,
    required this.repliedAt,
  });

  factory ReceiverReply.fromJson(Map<String, dynamic> json) {
    return ReceiverReply(
      id: json['_id'] ?? json['id'] ?? '',
      contactId: json['contactId'] ?? '',
      contactName: json['contactName'] ?? 'Contact',
      message: json['message'] ?? '',
      repliedAt: json['repliedAt'] != null
          ? DateTime.parse(json['repliedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'contactName': contactName,
      'message': message,
      'repliedAt': repliedAt.toIso8601String(),
    };
  }
}

// ============ EMERGENCY ============
class Emergency {
  final String id;
  final UserModel? userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // active, resolved, cancelled
  final List<LocationPoint> locationPoints; // ✅ Now LocationPoint is defined
  LocationPoint? currentLocation; // ✅ Now LocationPoint is defined
  final List<String> notifiedContacts;
  final List<EmergencyImage> cameraImages; // ✅ Now EmergencyImage is defined
  final bool isVideoActive;
  final DateTime? createdAt;
  final List<ReceiverReply> receiverReplies; // ✅ Now ReceiverReply is defined
  final bool isWebStreamActive;
  final String webStreamToken;

  Emergency({
    required this.id,
    required this.userId,
    required this.startTime,
    this.endTime,
    this.status = 'active',
    this.locationPoints = const [],
    this.currentLocation,
    this.notifiedContacts = const [],
    this.cameraImages = const [],
    this.isVideoActive = false,
    this.createdAt,
    this.receiverReplies = const [],
    this.isWebStreamActive = false,
    this.webStreamToken = '',
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] != null && json['userId'] is Map<String, dynamic>
          ? UserModel.fromJson(json['userId'])
          : null,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'active',

      locationPoints: json['locationPoints'] is List
          ? (json['locationPoints'] as List)
                .map((p) => LocationPoint.fromJson(p))
                .toList()
          : [],

      currentLocation:
          json['currentLocation'] != null && json['currentLocation'] is Map
          ? LocationPoint.fromJson(json['currentLocation'])
          : null,

      notifiedContacts: json['notifiedContacts'] is List
          ? List<String>.from(json['notifiedContacts'])
          : [],

      cameraImages: json['cameraImages'] is List
          ? (json['cameraImages'] as List)
                .map((i) => EmergencyImage.fromJson(i))
                .toList()
          : [],

      isVideoActive: json['isVideoActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,

      receiverReplies: json['receiverReplies'] is List
          ? (json['receiverReplies'] as List)
                .map((r) => ReceiverReply.fromJson(r))
                .toList()
          : [],

      isWebStreamActive: json['isWebStreamActive'] ?? false,
      webStreamToken: json['webStreamToken'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId?.toJson(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'status': status,
      'locationPoints': locationPoints.map((p) => p.toJson()).toList(),
      'currentLocation': currentLocation?.toJson(),
      'notifiedContacts': notifiedContacts,
      'cameraImages': cameraImages.map((i) => i.toJson()).toList(),
      'isVideoActive': isVideoActive,
      'createdAt': createdAt?.toIso8601String(),
      'receiverReplies': receiverReplies.map((r) => r.toJson()).toList(),
      'isWebStreamActive': isWebStreamActive,
      'webStreamToken': webStreamToken,
    };
  }
}
