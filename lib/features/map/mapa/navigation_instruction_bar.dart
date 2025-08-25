import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NavigationInstructionBar extends StatelessWidget {
  final String maneuverType;       // e.g. "straight", "turn-left", "roundabout", "merge", "uturn-right", etc.
  final double distanceMeters;     // e.g. 1108.0 (meters)
  final String? nextManeuverText;  // textual action like "skręć w prawo" (from logic)
    final String? streetName;        // e.g. "ul. Piękna" or road number e.g. "A4"

  final List<dynamic>? steps;
  final int? currentStepIndex;
  const NavigationInstructionBar({
    super.key,
    required this.maneuverType,
    required this.distanceMeters,
    this.nextManeuverText,
    this.streetName,
    this.steps,
    this.currentStepIndex,
  });

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000.0);
      return km >= 10 ? '${km.toStringAsFixed(0)} km' : '${km.toStringAsFixed(1)} km';
    } else {
      return '${meters.round()} m';
    }
  }

  IconData _iconForManeuver(String m) {
    final mm = m.toLowerCase();
    if (mm.contains('left') || mm.contains('lewo')) return Icons.turn_left;
    if (mm.contains('right') || mm.contains('prawo')) return Icons.turn_right;
    if (mm.contains('roundabout') || mm.contains('rondo')) return Icons.circle;
    if (mm.contains('merge')) return Icons.merge_type;
    if (mm.contains('uturn')) return Icons.loop;
    if (mm.contains('fork')) return Icons.call_split;
    if (mm.contains('straight')) return Icons.arrow_upward;
    return Icons.navigation;
  }

  String _actionText(String? provided, String maneuverType) {
    if (provided != null && provided.trim().isNotEmpty && provided != 'kontynuuj') {
      return provided;
    }
    final m = maneuverType.toLowerCase();
    if (m.contains('left') || m.contains('lewo')) return 'skręć w lewo';
    if (m.contains('right') || m.contains('prawo')) return 'skręć w prawo';
    if (m.contains('roundabout') || m.contains('rondo')) return 'na rondzie zjedź odpowiednim zjazdem';
    if (m.contains('merge')) return 'włącz się do ruchu';
    if (m.contains('uturn')) return 'zawróć';
    if (m.contains('straight')) return 'jedź prosto';
    return 'kontynuuj';
  }

  
  String? _extractRoadName(String instruction) {
    if (instruction.trim().isEmpty) return null;
    final instr = instruction;
    final streetPattern = RegExp(r'\b(?:ul(?:\.|ica)?|aleja|al(?:\.)?|pl(?:\.|ac)?|plac|osiedle|os\.)\s+([A-ZĄĆĘŁŃÓŚŹŻ][\wąęćłńóśźż\.\- ]{1,80})', caseSensitive: false);
    final m1 = streetPattern.firstMatch(instr);
    if (m1 != null) return m1.group(1)?.trim();

    final ontoPattern = RegExp(r'\b(?:onto|on|to|w kierunku|w stronę|wjazd na)\s+([A-ZĄĆĘŁŃÓŚŹŻ][\wąęćłńóśźż\.\- ]{1,80})', caseSensitive: false);
    final m2 = ontoPattern.firstMatch(instr);
    if (m2 != null) return m2.group(1)?.trim();

    final quotePattern = RegExp('["\\\']([A-ZĄĆĘŁŃÓŚŹŻ][^"\\\']{2,80})["\\\']');
    final m3 = quotePattern.firstMatch(instr);
    if (m3 != null) return m3.group(1)?.trim();

    return null;
  }

  String? _extractRoadNumber(String instruction) {
    if (instruction.trim().isEmpty) return null;
    final numPattern = RegExp(r'\b([AS]\d{1,3}|DK\d{1,3}|DW\d{1,3}|E\d{1,3})\b', caseSensitive: false);
    final m = numPattern.firstMatch(instruction);
    if (m != null) return m.group(1)?.toUpperCase();
    return null;
  }

@override
  Widget build(BuildContext context) {
    final action = _actionText(nextManeuverText, maneuverType);
    final distLabel = _formatDistance(distanceMeters);
    final primaryLine = 'Za $distLabel $action';
    final String secondaryLine = (() {
      if (streetName != null && streetName!.trim().isNotEmpty) return streetName!;
      if (steps != null && currentStepIndex != null) {
        for (int i = currentStepIndex! + 1; i < steps!.length && i <= currentStepIndex! + 6; i++) {
          try {
            final instrRaw = (steps![i]['html_instructions'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '');
            final name = _extractRoadName(instrRaw);
            if (name != null && name.trim().isNotEmpty) return name;
            final probableNamePattern = RegExp(r'([A-ZĄĆĘŁŃÓŚŹŻ][a-ząęćłńóśźż][\wąęćłńóśźż\.\- ]{1,80})');
            final probableMatch = probableNamePattern.firstMatch(instrRaw);
            if (probableMatch != null) {
              final candidate = probableMatch.group(1)?.trim();
              if (candidate != null && !RegExp(r'^[A-Z]{1,3}\d').hasMatch(candidate) && candidate.length > 2) {
                return candidate;
              }
            }
            final num = _extractRoadNumber(instrRaw);
            if (num != null && num.trim().isNotEmpty) return num;
          } catch (e) {
            // ignore
          }
        }
      }
      return '';
    })();

    return Container(
      margin: const EdgeInsets.only(top: 40, left: 12, right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F24),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          // icon
          Container(
            decoration: BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(8),
            child: Icon(
              _iconForManeuver(maneuverType),
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          // text column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primaryLine,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (secondaryLine.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    secondaryLine,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
