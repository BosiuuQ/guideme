import 'package:flutter/material.dart';
import 'package:guide_me/features/clubs/club_details_view.dart';

Future<void> showClubPreview(BuildContext context, Map<String, dynamic> club) {
  final members = (club['members'] as List<dynamic>?) ?? [];
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF0C0F1C),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: club['logo_url'] != null && club['logo_url'] != "" ? NetworkImage(club['logo_url']) : null,
                  backgroundColor: Colors.white12,
                  child: club['logo_url'] == null || club['logo_url'] == "" ? const Icon(Icons.group, color: Colors.white) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(club['name'] ?? "Klub", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(club['bio'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 13), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text("Członkowie", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))),
            const SizedBox(height: 8),
            SizedBox(
              height: 72,
              child: members.isEmpty
                  ? const Center(child: Text("Brak członków", style: TextStyle(color: Colors.white54)))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final m = members[index] as Map<String, dynamic>;
                        final avatar = m['avatar'] as String?;
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: avatar != null && avatar != "" ? NetworkImage(avatar) : null,
                              backgroundColor: Colors.white12,
                              child: avatar == null || avatar == "" ? const Icon(Icons.person, color: Colors.white) : null,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 64,
                              child: Text(m['nickname'] ?? "?", textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ClubDetailsView(club: club)));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB3CDE0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Zamknij"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}