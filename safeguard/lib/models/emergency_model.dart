class Emergency {
  final String id;
  final String userId;
  final DateTime startTime;
  final DateTime? endTime;
  final String status; // active, resolved, cancelled
  final List<LocationPoint> locationPoints;
  LocationPoint? currentLocation;
  final List<String> notifiedContacts;
  final List<EmergencyImage> cameraImages;
  final bool isVideoActive;
  final DateTime? createdAt;

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
  });

  factory Emergency.fromJson(Map<String, dynamic> json) {
    return Emergency(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? '',
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      status: json['status'] ?? 'active',
      locationPoints:
          (json['locationPoints'] as List?)
              ?.map((p) => LocationPoint.fromJson(p))
              .toList() ??
          [],
      currentLocation: json['currentLocation'] != null
          ? LocationPoint.fromJson(json['currentLocation'])
          : null,
      notifiedContacts: List<String>.from(json['notifiedContacts'] ?? []),
      cameraImages:
          (json['cameraImages'] as List?)
              ?.map((i) => EmergencyImage.fromJson(i))
              .toList() ??
          [],
      isVideoActive: json['isVideoActive'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }
}

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
}
