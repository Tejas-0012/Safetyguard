import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;

  Future<bool> checkSmsPermission() async {
    print('📱 Checking SMS permission...');
    final status = await Permission.sms.request();
    print('📱 SMS permission status: $status');
    return status.isGranted;
  }

  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    print('📱 ===== SENDING SMS =====');
    print('📱 To: $phoneNumber');
    print('📱 Message: $message');

    try {
      final hasPermission = await checkSmsPermission();
      if (!hasPermission) {
        print('❌ SMS permission not granted');
        return false;
      }

      print('📱 Sending SMS via Telephony...');

      await _telephony.sendSms(to: phoneNumber, message: message);

      print('✅ SMS sent successfully to $phoneNumber');
      return true;
    } catch (e) {
      print('❌ Error sending SMS: $e');
      return false;
    }
  }

  Future<bool> sendEmergencyAlert({
    required String contactName,
    required String contactPhone,
    required String userName,
    required double latitude,
    required double longitude,
    required String emergencyId,
  }) async {
    print('📱 ===== SENDING EMERGENCY SMS =====');
    print('📱 Contact: $contactName');
    print('📱 Phone: $contactPhone');
    final lat = latitude;
    final long = longitude;
    final name = userName;
    final id = emergencyId;
    final message = '''EMERGENCY ALERT $name has activated an SOS alert! 
        Current Location:https://www.google.com/maps?q=$lat,$long ''';
    return await sendSms(phoneNumber: contactPhone, message: message.trim());
  }

  Future<bool> sendEmergencyAlertWithWebLink({
    required String contactName,
    required String contactPhone,
    required String userName,
    required double latitude,
    required double longitude,
    required String emergencyId,
    required String webUrl,
  }) async {
    final message =
        '''
🚨 EMERGENCY ALERT

$userName has activated an SOS alert!

📍 Current Location:
https://www.google.com/maps?q=$latitude,$longitude

🔴 View Live Location & Images:
$webUrl

Reply "I'm coming" to let them know!

Please check the SafeGuard app for live updates.
    ''';

    return await sendSms(phoneNumber: contactPhone, message: message.trim());
  }

  // ✅ NEW: Listen for incoming SMS replies
  void listenForReplies(Function(String sender, String message) onReply) {
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) {
        final sender = message.address ?? 'Unknown'; // ✅ 'address' not 'sender'
        final body = message.body ?? '';
        print('📩 SMS Received from: ${sender}');
        print('📩 Message: ${message.body}');

        // Check if message is a reply to emergency
        if (message.body?.toLowerCase().contains('coming') == true) {
          onReply(sender!, message.body!);
        }
      },
    );
  }
}
