import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class InstagramReportService {
  static final _client = Supabase.instance.client;

  static const List<String> predefinedReasons = [
    "Spam lub oszustwo",
    "Treści nieodpowiednie",
    "Mowa nienawiści",
    "Fałszywe informacje",
    "Inne",
  ];

  static Future<String?> report({
    required String type, // 'post' lub 'comment'
    required String reportedItemId,
    required String reason,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return "Brak zalogowanego użytkownika.";
    final userId = user.id;

    final existing = await _client
        .from('zgloszenia_ig')
        .select('created_at')
        .eq('reported_item_id', reportedItemId)
        .eq('reported_by', userId)
        .eq('type', type)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final String rawTimestamp = existing['created_at'];
      print("🕒 Ostatnie zgłoszenie: $rawTimestamp");

      try {
        final lastReported = DateTime.parse(rawTimestamp);
        final diff = DateTime.now().difference(lastReported);
        print("📏 Różnica czasu: $diff");

        if (diff.inHours < 24) {
          print("⛔ Zablokowane – ostatnie zgłoszenie $diff temu");
          return "Zgłaszałeś to już w ciągu ostatnich 24h.";
        }
      } catch (e) {
        print("❌ Błąd parsowania daty: $e");
      }
    }

    await _client.from('zgloszenia_ig').insert({
      'type': type,
      'reported_item_id': reportedItemId,
      'reported_by': userId,
      'reason': reason,
      'created_at': DateTime.now().toIso8601String(),
    });

    final userData = await _client
        .from('users')
        .select('nickname')
        .eq('id', userId)
        .maybeSingle();
    final nickname = userData?['nickname'] ?? 'Nieznany';

    await _sendDiscordAlert(
      type: type,
      reportedItemId: reportedItemId,
      reason: reason,
      reporterId: userId,
      reporterNickname: nickname,
    );

    return null;
  }

  static Future<void> _sendDiscordAlert({
    required String type,
    required String reportedItemId,
    required String reason,
    required String reporterId,
    required String reporterNickname,
  }) async {
    const webhookUrl = 'https://discord.com/api/webhooks/1372988547090481296/J80TcVTnrOH70V1xDTBvVoRF43fAWgwmngsDgSPzYPw9CwPVnwFV1CDizk03DzlwkaT7'; // ← podmień

    String? content;
    String? imageUrl;

    if (type == 'post') {
      final post = await _client
          .from('instagram_posty')
          .select('caption, image_url')
          .eq('id', reportedItemId)
          .maybeSingle();
      content = post?['caption'];
      imageUrl = post?['image_url'];
    } else {
      final comment = await _client
          .from('instagram_post_comments')
          .select('post_id, comment_text')
          .eq('id', reportedItemId)
          .maybeSingle();
      final commentText = comment?['comment_text'];
      content = (commentText != null && commentText.length > 200)
          ? '${commentText.substring(0, 200)}...'
          : commentText;
    }

    final embed = {
      "title": type == 'post'
          ? "🚩 Zgłoszono post Instagram"
          : "💬 Zgłoszono komentarz Instagram",
      "color": type == 'post' ? 16733525 : 15844367,
      "fields": [
        {
          "name": type == 'post' ? "Opis posta" : "Treść komentarza",
          "value": content ?? "Brak treści"
        },
        {"name": "Typ", "value": type, "inline": true},
        {"name": "ID elementu", "value": reportedItemId, "inline": true},
        {"name": "Powód", "value": reason},
        {"name": "Zgłoszone przez", "value": "$reporterNickname (`$reporterId`)"},
      ],
      if (type == 'post' && imageUrl != null && imageUrl.isNotEmpty)
        "image": {"url": imageUrl},
      "timestamp": DateTime.now().toUtc().toIso8601String()
    };

    await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"embeds": [embed]}),
    );
  }

  static Future<void> showReasonDialog({
    required BuildContext context,
    required void Function(String reason) onSubmit,
  }) async {
    String? selected;
    String custom = '';

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zgłoś treść"),
        content: StatefulBuilder(
          builder: (_, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...predefinedReasons.map((r) => RadioListTile<String>(
                    title: Text(r),
                    value: r,
                    groupValue: selected,
                    onChanged: (v) => setState(() => selected = v),
                  )),
              if (selected == 'Inne')
                TextField(
                  decoration: const InputDecoration(hintText: 'Wpisz swój powód'),
                  onChanged: (v) => custom = v,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Anuluj"),
          ),
          ElevatedButton(
            onPressed: () {
              final result = selected == 'Inne' ? custom.trim() : selected;
              if (result != null && result.isNotEmpty) {
                Navigator.pop(ctx);
                onSubmit(result);
              }
            },
            child: const Text("Zgłoś"),
          )
        ],
      ),
    );
  }
}
