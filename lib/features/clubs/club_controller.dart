import 'package:supabase_flutter/supabase_flutter.dart';

class ClubController {
  final supabase = Supabase.instance.client;

  // Sprawdź, czy użytkownik jest w klubie
  Future<bool> isInClub(String userId) async {
    final result = await supabase
        .from('clubs_members')
        .select('club_id')
        .eq('user_id', userId)
        .maybeSingle();
    return result != null;
  }

  // Sprawdź, czy ma zaproszenie do jakiegokolwiek klubu
  Future<bool> hasPendingInvitation(String userId) async {
    final result = await supabase
        .from('club_invitations')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();
    return result != null;
  }

  // Sprawdź, czy można zaprosić użytkownika
  Future<bool> canInviteToClub(String userId) async {
    final isAlreadyInClub = await isInClub(userId);
    final hasInvitation = await hasPendingInvitation(userId);

    return !isAlreadyInClub && !hasInvitation;
  }

  // Sprawdź, czy może zarządzać klubem
  Future<bool> canManageClub(String clubId, String userId) async {
    final result = await supabase
        .from('clubs_members')
        .select('rola')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();

    final rola = result?['rola'];
    return rola == 'Lider' || rola == 'Zastepca';
  }

  // Sprawdź, czy Lider/Właściciel
  Future<bool> isLeaderOrOwner(String clubId, String userId) async {
    final result = await supabase
        .from('clubs_members')
        .select('rola')
        .eq('club_id', clubId)
        .eq('user_id', userId)
        .maybeSingle();

    final rola = result?['rola'];
    return rola == 'Lider' || rola == 'Właściciel';
  }

  // Pobierz dane klubu użytkownika
  Future<Map<String, dynamic>?> getMyClub(String userId) async {
    final membership = await supabase
        .from('clubs_members')
        .select('club_id, rola, clubs(*)')
        .eq('user_id', userId)
        .maybeSingle();

    if (membership == null) return null;

    final club = membership['clubs'];
    final clubId = membership['club_id'];
    final userRole = membership['rola'];

    final members = await supabase
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);

    final userIds = members.map((m) => m['user_id'] as String).toList();

    final levelsResponse = await supabase
        .from('users')
        .select('account_lvl')
        .inFilter('id', userIds);

    final kmsResponse = await supabase
        .from('user_distance')
        .select('total_km')
        .inFilter('user_id', userIds);

    final totalLevels = levelsResponse.fold<double>(
      0.0,
      (sum, item) => sum + ((item['account_lvl'] ?? 0) as num).toDouble(),
    );
    final avgLevel = levelsResponse.isEmpty
        ? 0
        : (totalLevels / levelsResponse.length).round();

    final totalKm = kmsResponse.fold<double>(
      0.0,
      (sum, item) => sum + ((item['total_km'] ?? 0) as num).toDouble(),
    );
    final avgKm = kmsResponse.isEmpty
        ? 0
        : (totalKm / kmsResponse.length).round();

    return {
      ...club,
      'average_level': avgLevel,
      'average_km': avgKm,
      'members': userIds.length,
      'user_rola': userRole,
    };
  }

  // Utwórz klub
  Future<void> createClub({
    required String userId,
    required String name,
    required String logoUrl,
    required String bannerUrl,
    required String bio,
    required String style,
    bool isOpen = true,
  }) async {
    final club = await supabase.from('clubs').insert({
      'name': name,
      'logo_url': logoUrl,
      'banner_url': bannerUrl,
      'bio': bio,
      'style': style,
      'is_open': isOpen,
    }).select().single();

    await supabase.from('clubs_members').insert({
      'user_id': userId,
      'club_id': club['id'],
      'rola': 'Lider',
    });
  }

  // Lista członków
  Future<List<Map<String, dynamic>>> getClubMembers(String clubId) async {
    final result = await supabase
        .from('clubs_members')
        .select('id, rola, user_id, users(nickname, avatar_url, account_lvl)')
        .eq('club_id', clubId);
    return List<Map<String, dynamic>>.from(result);
  }

  // Zmień rolę (awans/degradacja)
  Future<void> changeRole(String memberId, String newRole) async {
    await supabase
        .from('clubs_members')
        .update({'rola': newRole})
        .eq('id', memberId);
  }

  // Usuń członka
  Future<void> removeMember(String memberId) async {
    await supabase.from('clubs_members').delete().eq('id', memberId);
  }

  // Wydarzenia
  Future<void> createClubEvent({
    required String clubId,
    required String title,
    required String location,
    required String eventDate,
  }) async {
    await supabase.from('club_events').insert({
      'club_id': clubId,
      'title': title,
      'location': location,
      'event_date': eventDate,
    });

    await supabase.rpc('increment_event_count', params: {'club_id': clubId});
  }

  Future<List<Map<String, dynamic>>> getClubEvents(String clubId) async {
    final result = await supabase
        .from('club_events')
        .select()
        .eq('club_id', clubId)
        .order('event_date', ascending: true);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> deleteClubEvent(String eventId) async {
    await supabase.from('club_events').delete().eq('id', eventId);
  }

  // Czat
  Future<List<Map<String, dynamic>>> getChatMessages(String clubId) async {
    final result = await supabase
        .from('club_chat')
        .select()
        .eq('club_id', clubId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(result);
  }

  Future<void> sendMessage({
    required String clubId,
    required String userId,
    required String nickname,
    required String avatarUrl,
    required String message,
  }) async {
    await supabase.from('club_chat').insert({
      'club_id': clubId,
      'user_id': userId,
      'nickname': nickname,
      'avatar_url': avatarUrl,
      'message': message,
    });
  }
}
