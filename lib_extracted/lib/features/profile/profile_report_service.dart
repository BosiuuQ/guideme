import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileReportService {
  static final _client = Supabase.instance.client;

  static Future<void> reportUser(String reportedUserId, String reason) async {
    final reporter = _client.auth.currentUser;
    if (reporter == null) throw Exception("Użytkownik nie jest zalogowany.");

    final existing = await _client
        .from('zgloszenia_profile')
        .select('created_at')
        .eq('reporter_user_id', reporter.id)
        .eq('reported_user_id', reportedUserId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null) {
      final lastReportedAt = DateTime.parse(existing['created_at']);
      final diff = DateTime.now().difference(lastReportedAt);
      if (diff.inMinutes < 60) {
        throw Exception("Możesz zgłosić ten profil tylko raz na godzinę.");
      }
    }

    final reporterData = await _client
        .from('users')
        .select('nickname')
        .eq('id', reporter.id)
        .maybeSingle();

    final reportedData = await _client
        .from('users')
        .select('nickname')
        .eq('id', reportedUserId)
        .maybeSingle();

    final reporterNickname = reporterData?['nickname'] ?? 'Nieznany';
    final reportedNickname = reportedData?['nickname'] ?? 'Nieznany';

    await _client.from('zgloszenia_profile').insert({
      'reported_user_id': reportedUserId,
      'reporter_user_id': reporter.id,
      'reason': reason,
    });

    await _sendDiscordAlert(
      reporterId: reporter.id,
      reporterNickname: reporterNickname,
      reportedId: reportedUserId,
      reportedNickname: reportedNickname,
      reason: reason,
    );
  }

  static Future<void> _sendDiscordAlert({
    required String reporterId,
    required String reporterNickname,
    required String reportedId,
    required String reportedNickname,
    required String reason,
  }) async {
    const webhookUrl = 'https://discord.com/api/webhooks/1372981479126204549/g55fbi1GWWiyp8sFXbgzKo79c_XX3ZlUDDJfeMmGgpIqWoSdzwT-2MQQuhKXCUbm6MI7'; // <- Podmień na swój

    final embed = {
      "embeds": [
        {
          "title": "🛑 Zgłoszenie profilu",
          "color": 16711680,
          "fields": [
            {
              "name": "👤 Zgłoszony",
              "value": "`$reportedNickname` (`$reportedId`)",
              "inline": false
            },
            {
              "name": "📣 Powód",
              "value": reason,
              "inline": false
            },
            {
              "name": "📨 Zgłaszający",
              "value": "`$reporterNickname` (`$reporterId`)",
              "inline": false
            }
          ],
          "timestamp": DateTime.now().toUtc().toIso8601String()
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(embed),
      );

      if (response.statusCode != 204 && response.statusCode != 200) {
        print('❌ Błąd Discord webhook: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('❌ Wyjątek przy wysyłaniu na Discorda: $e');
    }
  }
}
