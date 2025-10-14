import 'package:flutter/material.dart';
import 'package:guide_me/features/clubs/club_details_view.dart';

Future<void> showClubPreview(BuildContext context, Map<String, dynamic> club) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0C0F1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
      builder: (ctx) {
        return SafeArea(
          bottom: true, // uwzględniamy pasek telefonu
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Nagłówek
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: club['logo_url'] != null &&
                          club['logo_url'] != ""
                          ? NetworkImage(club['logo_url'])
                          : null,
                      backgroundColor: Colors.white12,
                      child: club['logo_url'] == null || club['logo_url'] == ""
                          ? const Icon(Icons.group, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(club['name'] ?? "Klub",
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text(club['bio'] ?? "",
                              style:
                              const TextStyle(color: Colors.white70,
                                  fontSize: 13),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Przyciski pod SafeArea
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => ClubDetailsView(club: club)));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB3CDE0),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Szczegóły"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Zamknij"),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      });

      }
