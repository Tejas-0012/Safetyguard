class EmergencyContact {
  final String id;
  final String userId;
  final String name;
  final String phone;
  final String? email;
  final String? relation;
  final bool isNotified;
  final DateTime? createdAt;

  EmergencyContact({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    this.email,
    this.relation,
    this.isNotified = false,
    this.createdAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] ?? json['_id'] ?? '',
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'],
      relation: json['relation'],
      isNotified: json['isNotified'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'phone': phone,
      'email': email,
      'relation': relation,
      'isNotified': isNotified,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}
