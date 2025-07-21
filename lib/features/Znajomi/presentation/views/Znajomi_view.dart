import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/core/constants/app_colors.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/znajomi/znajomi_backend.dart';
import 'package:guide_me/features/znajomi/domain/friend_model.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


class ZnajomiView extends StatefulWidget {
  const ZnajomiView({Key? key}) : super(key: key);

  @override
  State<ZnajomiView> createState() => _ZnajomiViewState();
}

class _ZnajomiViewState extends State<ZnajomiView> {
  late Future<List<Friend>> friendsFuture;
  late Future<List<Friend>> invitationsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    friendsFuture = ZnajomiBackend.getFriends();
    invitationsFuture = ZnajomiBackend.getFriendInvitations();
  }

  String formatLastOnline(String? isoString) {
    if (isoString == null) return "Offline";
    try {
      final lastOnline = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final diff = now.difference(lastOnline);

      if (diff.inMinutes <= 8) {
        return "Aktywny";
      } else if (diff.inMinutes < 60) {
        return "Aktywny: ${diff.inMinutes}m temu";
      } else if (diff.inHours < 24) {
        return "Aktywny: ${diff.inHours}h temu";
      } else {
        final formatted = DateFormat('dd.MM.yyyy HH:mm').format(lastOnline);
        return "⚫ Aktywny: $formatted";
      }
    } catch (_) {
      return "Offline";
    }
  }

  Color _statusColor(String? isoString) {
    if (isoString == null) return Colors.grey;
    try {
      final lastOnline = DateTime.parse(isoString).toLocal();
      final diff = DateTime.now().difference(lastOnline);

      if (diff.inMinutes <= 8) {
        return Colors.green;
      } else if (diff.inMinutes < 60) {
        return Colors.orange;
      } else {
        return Colors.grey;
      }
    } catch (_) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        title: const Text('Znajomi'),
        backgroundColor: AppColors.darkBlue,
        actions: [
          FutureBuilder<List<Friend>>(
            future: invitationsFuture,
            builder: (context, snapshot) {
              final invitationCount = snapshot.data?.length ?? 0;
              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications, size: 28),
                    if (invitationCount > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                          child: Center(
                            child: Text(
                              '$invitationCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () async {
                  final invitations = await invitationsFuture;
                  _showInvitationsDialog(invitations);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed(AppRoutes.searchUser),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPremiumChatTile(),
          Expanded(
            child: FutureBuilder<List<Friend>>(
              future: friendsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Brak znajomych", style: TextStyle(color: Colors.white70)));
                }

                final friends = snapshot.data!;
                return ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final friend = friends[index];
                    return GestureDetector(
                      onTap: () => context.pushNamed(
                        AppRoutes.chatView,
                        extra: {
                          'friendId': friend.id,
                          'friendNickname': friend.nickname,
                        },
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1F1F2E), Color(0xFF2C2C3E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 26,
                                  backgroundColor: Colors.white24,
                                  backgroundImage: friend.avatar != null
                                      ? NetworkImage(friend.avatar!)
                                      : null,
                                  child: friend.avatar == null
                                      ? const Icon(Icons.person, color: Colors.white)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: _statusColor(friend.lastOnline),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.black, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    friend.nickname,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formatLastOnline(friend.lastOnline),
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumChatTile() {
    return FutureBuilder<bool>(
      future: ZnajomiBackend.isCurrentUserPremium(),
      builder: (context, snapshot) {
        if (snapshot.data != true) return const SizedBox.shrink();
        return ListTile(
          tileColor: Colors.white12,
          leading: const Icon(Icons.workspace_premium, color: Colors.amber),
          title: const Text("💎 Premium Chat", style: TextStyle(color: Colors.white)),
          onTap: () => context.pushNamed(AppRoutes.premiumChat),
        );
      },
    );
  }

  void _showInvitationsDialog(List<Friend> invitations) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBlue,
        title: const Text('Zaproszenia do znajomych', style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: invitations.length,
            itemBuilder: (context, index) {
              final friend = invitations[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend.avatar != null ? NetworkImage(friend.avatar!) : null,
                  backgroundColor: Colors.grey.shade800,
                  child: friend.avatar == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                title: Text(friend.nickname, style: const TextStyle(color: Colors.white)),
                trailing: IconButton(
                  icon: const Icon(Icons.check, color: Colors.greenAccent),
                  onPressed: () async {
  await ZnajomiBackend.acceptFriendRequest(friend.requestId!);
  final currentUserId = Supabase.instance.client.auth.currentUser!.id;
  await ZnajomiBackend.removeOppositeFriendRequest(friend.id, currentUserId); // ⬅️ poprawione
  if (mounted) {
    Navigator.of(dialogContext).pop();
    setState(() => _loadData());
  }
},

                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text("Zamknij", style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }
}
