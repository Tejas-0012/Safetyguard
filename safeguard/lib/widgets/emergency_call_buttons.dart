import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import '../services/emergency_call_service.dart';

class EmergencyCallButtons extends StatelessWidget {
  /// Compact mode = single row of small chips (for monitoring screen)
  /// Full mode = grid of cards (for emergency mode screen)
  final bool compact;

  const EmergencyCallButtons({super.key, this.compact = false});

  static const List<Map<String, dynamic>> _emergencyNumbers = [
    {
      'label': 'Police',
      'number': '100',
      'icon': Icons.local_police,
      'color': Color(0xFF1E88E5),
    },
    {
      'label': 'Ambulance',
      'number': '108',
      'icon': Icons.local_hospital,
      'color': Color(0xFF43A047),
    },
    {
      'label': 'Fire',
      'number': '101',
      'icon': Icons.local_fire_department,
      'color': Color(0xFFF57C00),
    },
    {
      'label': 'All Emergency',
      'number': '112',
      'icon': Icons.emergency,
      'color': Color(0xFFE53935),
    },
    {
      'label': 'Women Helpline',
      'number': '1091',
      'icon': Icons.female,
      'color': Color(0xFF8E24AA),
    },
    {
      'label': 'Domestic Abuse',
      'number': '181',
      'icon': Icons.shield,
      'color': Color(0xFFD81B60),
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactRow(context);
    }
    return _buildFullGrid(context);
  }

  // ============ COMPACT (single scrollable row) ============
  Widget _buildCompactRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: _emergencyNumbers.map((e) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(context, e),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChip(BuildContext context, Map<String, dynamic> data) {
    final color = data['color'] as Color;
    return GestureDetector(
      onTap: () => EmergencyCallService.confirmAndDial(
        context: context,
        number: data['number'],
        label: data['label'],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data['icon'] as IconData, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              data['label'] as String,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              data['number'] as String,
              style: TextStyle(
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ FULL (grid of cards) ============
  Widget _buildFullGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.phone_in_talk, color: AppColors.danger, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Emergency Services',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'One tap to connect',
          style: TextStyle(fontSize: 12, color: AppColors.textLight),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.15,
          children: _emergencyNumbers.map((e) {
            return _buildCard(context, e);
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    final color = data['color'] as Color;
    return GestureDetector(
      onTap: () => EmergencyCallService.confirmAndDial(
        context: context,
        number: data['number'],
        label: data['label'],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppColors.radiusLarge),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(data['icon'] as IconData, color: color, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              data['label'] as String,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              data['number'] as String,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
