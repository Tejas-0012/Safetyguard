import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';

class SmsService {
  final Telephony _telephony = Telephony.instance;

  Future<bool> checkSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final hasPermission = await checkSmsPermission();
      if (!hasPermission) {
        throw Exception('SMS permission not granted');
      }

      await _telephony.sendSms(to: phoneNumber, message: message);

      return true;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
  }) async {
    final results = <String, bool>{};

    for (final phone in phoneNumbers) {
      final success = await sendSms(phoneNumber: phone, message: message);
      results[phone] = success;
    }

    return results;
  }

  Future<bool> sendEmergencyAlert({
    required String contactName,
    required String contactPhone,
    required String userName,
    required double latitude,
    required double longitude,
    required String emergencyId,
  }) async {
    final message =
        '''
🚨 EMERGENCY ALERT

$userName has activated an SOS alert!

📍 Current Location:
https://www.google.com/maps?q=$latitude,$longitude

🆘 Emergency ID: $emergencyId

Please check the SafeGuard app for live updates.
    ''';

    return await sendSms(phoneNumber: contactPhone, message: message);
  }
}
