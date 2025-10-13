import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/wydarzenia/models/event_model.dart';

class EventsBackend {
  final _client = Supabase.instance.client;

  Future<String?> getCurrentUserId() async {
    return _client.auth.currentUser?.id;
  }

  Future<List<Event>> fetchEvents() async {
    final response = await _client
        .from('events')
        .select()
        .order('start_time', ascending: true);

    return (response as List)
        .map((data) => Event.fromMap(data as Map<String, dynamic>))
        .toList();
  }

  Future<void> addEvent(Event event) async {
    await _client.from('events').insert({
      'title': event.title,
      'description': event.description,
      'location': event.location,
      'start_time': event.startTime.toIso8601String(),
      'end_time': event.endTime.toIso8601String(),
      'type': event.type,
      'image_url': event.imageUrl,
      'creator_id': event.creatorId,
    });
  }

  Future<void> toggleJoinEvent(String eventId) async {
    final userId = await getCurrentUserId();
    if (userId == null) return;

    final existing = await _client
        .from('event_participants')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('event_participants')
          .delete()
          .eq('id', existing['id']);
    } else {
      await _client.from('event_participants').insert({
        'event_id': eventId,
        'user_id': userId,
      });
    }
  }

  Future<bool> isUserJoined(String eventId) async {
    final userId = await getCurrentUserId();
    if (userId == null) return false;

    final res = await _client
        .from('event_participants')
        .select()
        .eq('event_id', eventId)
        .eq('user_id', userId)
        .maybeSingle();

    return res != null;
  }

  Future<List<Map<String, dynamic>>> getEventParticipants(String eventId) async {
    final res = await _client
        .from('event_participants')
        .select('user_id, users!auth_user_id(id, nickname, avatar)')
        .eq('event_id', eventId);

    return List<Map<String, dynamic>>.from(res);
  }
}
