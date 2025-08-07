import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NavigationInstructionBar extends StatelessWidget {
  final String maneuverType;       // np. "straight", "turn-left"
  final double distanceMeters;     // np. 1108.0
  final String? nextManeuverText;  // np. "skręć w prawo"
  final String? streetName;        // np. "ul. Piękna"

  const NavigationInstructionBar({
    super.key,
    required this.maneuverType,
    required this.distanceMeters,
    this.nextManeuverText,
    this.streetName,
  });

  IconData _getManeuverIcon(String type) {
    switch (type) {
      case 'turn-right':
        return Icons.turn_right;
      case 'turn-left':
        return Icons.turn_left;
      case 'straight':
        return Icons.arrow_upward;
      case 'merge':
        return Icons.merge_type;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_left;
      default:
        return Icons.navigation;
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = meters / 1000;
      return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
    } else {
      return '${meters.toInt()} m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40, left: 12, right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F24),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getManeuverIcon(maneuverType), color: Colors.cyanAccent, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  (maneuverType == 'straight')
                      ? 'Przez ${_formatDistance(distanceMeters)} jedź prosto'
                      : 'Za ${_formatDistance(distanceMeters)}: ${_getInstructionText(maneuverType)}',
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          if (streetName != null && streetName!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 40),
              child: Text(
                'w $streetName',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          if (nextManeuverText != null && nextManeuverText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 40),
              child: Text(
                'Następnie: $nextManeuverText',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  String _getInstructionText(String type) {
    switch (type) {
      case 'turn-right':
        return 'skręć w prawo';
      case 'turn-left':
        return 'skręć w lewo';
      case 'merge':
        return 'włącz się do ruchu';
      case 'uturn-left':
      case 'uturn-right':
        return 'zawróć';
      case 'straight':
        return 'jedź prosto';
      default:
        return 'kontynuuj';
    }
  }
}
