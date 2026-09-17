enum NotificationType { receiverReply, emergencyStart, emergencyEnd }

class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final String? emergencyId;
  final String? contactName;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.emergencyId,
    this.contactName,
    required this.timestamp,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['_id'] ?? json['id'] ?? '',
      type: _parseType(json['type']),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      emergencyId: json['emergencyId'],
      contactName: json['contactName'],
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isRead: json['isRead'] ?? false,
    );
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'reply':
        return NotificationType.receiverReply;
      case 'emergency_start':
        return NotificationType.emergencyStart;
      case 'emergency_end':
        return NotificationType.emergencyEnd;
      default:
        return NotificationType.receiverReply;
    }
  }
}
