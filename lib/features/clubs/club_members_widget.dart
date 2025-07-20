import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubMembersWidget extends StatefulWidget {
  final String clubId;

  const ClubMembersWidget({super.key, required this.clubId});

  @override
  State<ClubMembersWidget> createState() => _ClubMembersWidgetState();
}

class _ClubMembersWidgetState extends State<ClubMembersWidget> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> members = [];
  Map<String, dynamic>? currentUserMember;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final response = await supabase
        .from('clubs_members')
        .select('''
          id, user_id, rola,
          users!fk_clubs_members_user(nickname, avatar, account_lvl)
        ''')
        .eq('club_id', widget.clubId)
        .order('rola', ascending: true);

    final List<Map<String, dynamic>> fetched =
        List<Map<String, dynamic>>.from(response);

    setState(() {
      members = fetched;
      currentUserMember = fetched.firstWhere(
        (m) => m['user_id'] == userId,
        orElse: () => {},
      );
      isLoading = false;
    });
  }

  Future<void> updateRola(String memberId, String newRola) async {
    await supabase
        .from('clubs_members')
        .update({'rola': newRola})
        .eq('id', memberId);
    await loadMembers();
  }

  Future<void> removeMember(String memberId) async {
    await supabase.from('clubs_members').delete().eq('id', memberId);
    await loadMembers();
  }

  bool get isLider => currentUserMember?['rola'] == 'Lider';
  bool get isZastepca => currentUserMember?['rola'] == 'Zastepca';

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (members.isEmpty) {
      return const Center(
        child: Text("Brak członków", style: TextStyle(color: Colors.white70)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: members.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final member = members[index];
        final user = member['users'] ?? {};
        final isSelf = member['user_id'] == supabase.auth.currentUser?.id;
        final String memberRola = member['rola'];
        final String memberId = member['id'];

        return Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: user['avatar'] != null
                  ? NetworkImage(user['avatar'])
                  : null,
              backgroundColor: Colors.white12,
              child: user['avatar'] == null
                  ? const Icon(Icons.person, color: Colors.white54)
                  : null,
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(user['nickname'] ?? 'Nieznany',
                      style: const TextStyle(color: Colors.white)),
                ),
                if (isLider && !isSelf && memberRola != 'Lider')
                  _buildPromoteDemoteButtons(memberId, memberRola),
              ],
            ),
            subtitle: Text(
              "Lvl ${user['account_lvl'] ?? 0} – $memberRola",
              style: const TextStyle(color: Colors.white70),
            ),
            trailing: isSelf ? null : _buildRemoveButton(memberId, memberRola),
          ),
        );
      },
    );
  }

  Widget _buildPromoteDemoteButtons(String memberId, String memberRola) {
    if (memberRola == 'Czlonek') {
      return TextButton(
        onPressed: () => updateRola(memberId, 'Zastepca'),
        child: const Text("Awansuj", style: TextStyle(color: Colors.amber)),
      );
    } else if (memberRola == 'Zastepca') {
      return TextButton(
        onPressed: () => updateRola(memberId, 'Czlonek'),
        child: const Text("Degraduj", style: TextStyle(color: Colors.orange)),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildRemoveButton(String memberId, String memberRola) {
    if (isLider || (isZastepca && memberRola == 'Czlonek')) {
      return IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        tooltip: "Usuń z klubu",
        onPressed: () => removeMember(memberId),
      );
    } else {
      return const SizedBox.shrink();
    }
  }
}
