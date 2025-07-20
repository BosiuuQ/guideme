import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/znajomi/domain/friend_model.dart';

class ZnajomiBackend {
  static final _supabase = Supabase.instance.client;

  static Future<List<Friend>> getFriends() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('friends')
        .select()
        .or('user1_id.eq.$userId,user2_id.eq.$userId');

    final List<Friend> friends = [];

    for (final item in response) {
      final otherId = item['user1_id'] == userId ? item['user2_id'] : item['user1_id'];
      final userResponse = await _supabase
          .from('users')
          .select('id, nickname, avatar, last_online')
          .eq('id', otherId)
          .maybeSingle();

      if (userResponse != null) {
        friends.add(Friend(
          id: userResponse['id'],
          nickname: userResponse['nickname'],
          avatar: userResponse['avatar'],
          lastOnline: userResponse['last_online'],
        ));
      }
    }

    return friends;
  }

  static Future<List<Friend>> getFriendInvitations() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('friend_requests')
        .select('id, from_user_id, users(nickname, avatar)')
        .eq('to_user_id', userId)
        .order('created_at', ascending: false);

    final data = response as List;

    return data.map((e) {
      final user = e['users'] ?? {};
      return Friend(
        id: e['from_user_id'],
        nickname: user['nickname'] ?? 'Nieznany',
        avatar: user['avatar'],
        lastOnline: null,
        requestId: e['id'],
      );
    }).toList();
  }

  static Future<void> acceptFriendRequest(String friendRequestId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final request = await _supabase
        .from('friend_requests')
        .select('from_user_id, to_user_id')
        .eq('id', friendRequestId)
        .maybeSingle();

    if (request == null) return;

    final fromUserId = request['from_user_id'];
    final toUserId = request['to_user_id'];

    await _supabase.from('friends').insert({
      'user1_id': fromUserId,
      'user2_id': toUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase.from('friend_requests').delete().eq('id', friendRequestId);
  }

  static Future<void> acceptFriend(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    await _supabase.from('friends').insert({
      'user1_id': currentUserId,
      'user2_id': otherUserId,
      'created_at': DateTime.now().toIso8601String(),
    });

    await _supabase
        .from('friend_requests')
        .delete()
        .eq('from_user_id', otherUserId)
        .eq('to_user_id', currentUserId);
  }

  static Future<void> rejectFriendRequest(String fromUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    await _supabase
        .from('friend_requests')
        .delete()
        .eq('from_user_id', fromUserId)
        .eq('to_user_id', currentUserId);
  }

  static Future<bool> isFriendRequestSent(String toUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final response = await _supabase
        .from('friend_requests')
        .select()
        .eq('from_user_id', currentUserId)
        .eq('to_user_id', toUserId)
        .maybeSingle();

    return response != null;
  }

  static Future<void> sendFriendRequest(String toUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || currentUserId == toUserId) return;

    final existing = await _supabase
        .from('friend_requests')
        .select()
        .eq('from_user_id', currentUserId)
        .eq('to_user_id', toUserId)
        .maybeSingle();

    if (existing != null) return;

    await _supabase.from('friend_requests').insert({
      'from_user_id': currentUserId,
      'to_user_id': toUserId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<String?> getCurrentUserId() async {
    return _supabase.auth.currentUser?.id;
  }

  static Future<bool> isCurrentUserPremium() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final response = await _supabase
        .from('users')
        .select('rola')
        .eq('id', userId)
        .maybeSingle();

    return response?['rola'] == 'Premium';
  }

  static Future<void> sendPremiumMessage(String messageText) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final userData = await _supabase
        .from('users')
        .select('nickname')
        .eq('id', user.id)
        .maybeSingle();

    await _supabase.from('premium_chat').insert({
      'sender_id': user.id,
      'sender_nickname': userData?['nickname'],
      'text': messageText,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Stream<List<Map<String, dynamic>>> premiumMessagesStream() {
    return _supabase
        .from('premium_chat')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .execute(); // ✅ realtime premium chat
  }

  static Stream<List<Map<String, dynamic>>> getMessages(String friendId) {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return const Stream.empty();

    final chatId = _generateChatId(currentUserId, friendId);

    return _supabase
        .from('private_messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at')
        .execute(); // ✅ realtime private chat
  }

  static Future<void> sendMessage(String friendId, String text) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    final chatId = _generateChatId(currentUserId, friendId);

    await _supabase.from('private_messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'receiver_id': friendId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static String _generateChatId(String a, String b) {
    final sorted = [a, b]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  static Future<bool> areFriends(String otherUserId) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return false;

    final response = await _supabase
        .from('friends')
        .select()
        .or('user1_id.eq.$currentUserId,user2_id.eq.$currentUserId');

    for (final row in response) {
      if (row['user1_id'] == otherUserId || row['user2_id'] == otherUserId) {
        return true;
      }
    }
    return false;
  }
}
