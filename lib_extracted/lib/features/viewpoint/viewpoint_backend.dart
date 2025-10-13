import 'dart:convert';
import 'dart:io';
import 'package:guide_me/features/viewpoint/domain/entity/viewpoint.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewpointBackend {
  static final _client = Supabase.instance.client;

  /// Uploaduje obraz z pliku [imageFile] do bucketa "punkty-widokowe"
  /// i zwraca publiczny URL.
  static Future<String> uploadViewpointImage(File imageFile, String fileName) async {
    final bytes = await imageFile.readAsBytes();
    await _client.storage.from('punkty-widokowe').uploadBinary(fileName, bytes);
    final publicUrl = _client.storage.from('punkty-widokowe').getPublicUrl(fileName);
    return publicUrl;
  }

//limit dodawania
static Future<bool> canAddViewpoint(String userId) async {
  final now = DateTime.now().toUtc();
  final oneHourAgo = now.subtract(const Duration(hours: 1));

  final result = await Supabase.instance.client
      .from('punkty_widokowe')
      .select('id')
      .eq('author_id', userId)
      .gte('created_at', oneHourAgo.toIso8601String());

  return result.isEmpty;
}

  /// Dodaje punkt widokowy do bazy danych wraz z przesłanym obrazem.
  static Future<void> addViewpoint(Viewpoint viewpoint, File imageFile, String fileName) async {
    final imageUrl = await uploadViewpointImage(imageFile, fileName);

    final Map<String, dynamic> insertData = {
      'title': viewpoint.title,
      'description': viewpoint.description,
      'author_id': viewpoint.creatorId,
      'location': jsonEncode({
        'lat': viewpoint.coordinates.y,
        'lng': viewpoint.coordinates.x,
      }),
      'image_url': imageUrl,
      'likes': viewpoint.likes,
    };

    await _client.from('punkty_widokowe').insert(insertData);
  }

  /// Pobiera wszystkie punkty widokowe wraz z danymi właściciela.
  static Future<List<Viewpoint>> getAllViewpoints() async {
    final data = await _client
        .from('punkty_widokowe')
        .select("*, user:users(nickname, avatar)")
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Viewpoint.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Pobiera punkty widokowe dodane przez danego użytkownika.
  static Future<List<Viewpoint>> getMyViewpoints(String userId) async {
    final data = await _client
        .from('punkty_widokowe')
        .select("*, user:users(nickname, avatar)")
        .eq('author_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Viewpoint.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Pobiera ulubione punkty widokowe (na podstawie listy ID).
  static Future<List<Viewpoint>> getFavouriteViewpoints(List<String> favouriteIds) async {
    final data = await _client
        .from('punkty_widokowe')
        .select("*, user:users(nickname, avatar)")
        .inFilter('id', favouriteIds);

    return (data as List)
        .map((e) => Viewpoint.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Pobiera punkty widokowe w pobliżu.
  static Future<List<Viewpoint>> getNearbyViewpoints(double lat, double lng, {double maxDistance = 0.5}) async {
    final data = await _client
        .from('punkty_widokowe')
        .select("*, user:users(nickname, avatar)");

    return (data as List)
        .map((e) => Viewpoint.fromMap(e as Map<String, dynamic>))
        .where((vp) {
          final dx = (vp.coordinates.x - lng).abs();
          final dy = (vp.coordinates.y - lat).abs();
          return dx < maxDistance && dy < maxDistance;
        })
        .toList();
  }

  /// Sprawdza, czy dany punkt jest ulubiony przez użytkownika.
  static Future<bool> isFavourite(String viewpointId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final fav = await _client
        .from('favourites')
        .select()
        .eq('user_id', userId)
        .eq('viewpoint_id', viewpointId)
        .maybeSingle();

    return fav != null;
  }

  /// Dodaje lub usuwa punkt z ulubionych.
  static Future<void> toggleFavourite(String viewpointId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await _client
        .from('favourites')
        .select()
        .eq('user_id', userId)
        .eq('viewpoint_id', viewpointId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('favourites')
          .delete()
          .eq('user_id', userId)
          .eq('viewpoint_id', viewpointId);
    } else {
      await _client.from('favourites').insert({
        'user_id': userId,
        'viewpoint_id': viewpointId,
      });
    }
  }
}
