import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SettingsBackend {
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> getUserProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};

    final data = await _client
        .from('users')
        .select()
        .eq('id', userId as Object)
        .maybeSingle();

    return data ?? {};
  }

  static Future<void> updateNickname(String nickname) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('users')
        .update({'nickname': nickname})
        .eq('id', userId as Object);

    await _client.auth.getUser(); // aktualizacja lokalna
  }

  static Future<void> updateBio(String bio) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('users')
        .update({'description': bio})
        .eq('id', userId as Object);

    await _client.auth.getUser();
  }

  static Future<void> updateMapStyle(String style) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('users')
        .update({'styl_mapy': style})
        .eq('id', userId as Object);

    await _client.auth.getUser();
  }

  static Future<void> updateAvatar(File file) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final bytes = await file.readAsBytes();
    final filename = 'avatars/${const Uuid().v4()}.jpg';

    final storage = _client.storage.from('avatars');
    await storage.uploadBinary(filename, bytes, fileOptions: const FileOptions(upsert: true));

    final publicUrl = storage.getPublicUrl(filename);
    await _client
        .from('users')
        .update({'avatar': publicUrl})
        .eq('id', userId as Object);

    await _client.auth.getUser();
  }
}
