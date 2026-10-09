import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

/// Service for quick-dialing emergency services
class EmergencyCallService {
  /// Dial a phone number using the device's phone app
  static Future<bool> dialNumber(BuildContext context, String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      } else {
        _showError(context, 'Cannot open dialer');
        return false;
      }
    } catch (e) {
      _showError(context, 'Failed to dial $number: $e');
      return false;
    }
  }

  static void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Confirm before dialing (safety measure)
  static Future<void> confirmAndDial({
    required BuildContext context,
    required String number,
    required String label,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk, color: Color(0xFFE53935)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Call $label?',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to call:',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Color(0xFF0D47A1)),
                  const SizedBox(width: 10),
                  Text(
                    '$label — $number',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.call, size: 18),
            label: const Text('CALL'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await dialNumber(context, number);
    }
  }
}
