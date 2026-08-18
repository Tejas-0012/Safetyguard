class User {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String? profileImage;
  final bool isEmergencyActive;
  final DateTime? emergencyStartTime;
  final Location? currentLocation;
  final List<String> contactIds;
  final DateTime? createdAt;

  User({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.profileImage,
    this.isEmergencyActive = false,
    this.emergencyStartTime,
    this.currentLocation,
    this.contactIds = const [],
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      isEmergencyActive: json['isEmergencyActive'] ?? false,
      emergencyStartTime: json['emergencyStartTime'] != null
          ? DateTime.parse(json['emergencyStartTime'])
          : null,
      currentLocation: json['currentLocation'] != null
          ? Location.fromJson(json['currentLocation'])
          : null,
      contactIds: List<String>.from(json['contactIds'] ?? []),
      createdAt:
          json['createdAt'] !=
              null // ✅ added
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'profileImage': profileImage,
      'isEmergencyActive': isEmergencyActive,
      'emergencyStartTime': emergencyStartTime?.toIso8601String(),
      'currentLocation': currentLocation?.toJson(),
      'contactIds': contactIds,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class Location {
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  Location({required this.latitude, required this.longitude, this.updatedAt});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
