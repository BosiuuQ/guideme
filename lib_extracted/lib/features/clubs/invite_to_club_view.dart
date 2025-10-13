import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InviteToClubView extends StatefulWidget {
  final String clubId;

  const InviteToClubView({super.key, required this.clubId});

  @override
  State<InviteToClubView> createState() => _InviteToClubViewState();
}

class _InviteToClubViewState extends State<InviteToClubView> {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> allUsers = [];
  List<Map<String, dynamic>> filteredUsers = [];
  bool isLoading = true;
  bool isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final member = await supabase
        .from('clubs_members')
        .select('rola')
        .eq('club_id', widget.clubId)
        .eq('user_id', userId)
        .maybeSingle();

    isAuthorized = member != null &&
        (member['rola'] == 'Lider' || member['rola'] == 'Zastepca');

    if (!isAuthorized) {
      setState(() => isLoading = false);
      return;
    }

    final usersResponse = await supabase
        .from('users')
        .select('id, nickname, avatar')
        .not('id', 'eq', userId);

    setState(() {
      allUsers = List<Map<String, dynamic>>.from(usersResponse);
      filteredUsers = allUsers;
      isLoading = false;
    });
  }

  void _filterUsers(String query) {
    final search = query.toLowerCase();
    setState(() {
      filteredUsers = allUsers
          .where((user) =>
              (user['nickname'] as String).toLowerCase().contains(search))
          .toList();
    });
  }

  Future<void> _sendInvite(String userId) async {
    final canInvite = await _canInviteToClub(userId);

    if (!canInvite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Nie można zaprosić – użytkownik już jest w klubie lub ma zaproszenie."),
        ),
      );
      return;
    }

    await supabase.from('club_invitations').insert({
      'club_id': widget.clubId,
      'user_id': userId,
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Zaproszenie wysłane")),
    );
  }

  Future<bool> _canInviteToClub(String userId) async {
    final isInClub = await supabase
        .from('clubs_members')
        .select('id')
        .eq('user_id', userId)
        .maybeSingle();

    if (isInClub != null) return false;

    final hasInvite = await supabase
        .from('club_invitations')
        .select('id')
        .eq('user_id', userId)
        .eq('club_id', widget.clubId)
        .maybeSingle();

    return hasInvite == null;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (!isAuthorized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Nie masz uprawnień", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Zaproś do klubu"),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: _filterUsers,
              decoration: InputDecoration(
                hintText: 'Wyszukaj użytkownika',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: Colors.white12,
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: user['avatar'] != null
                        ? NetworkImage(user['avatar'])
                        : null,
                    backgroundColor: Colors.white12,
                    child: user['avatar'] == null
                        ? const Icon(Icons.person, color: Colors.white70)
                        : null,
                  ),
                  title: Text(user['nickname'],
                      style: const TextStyle(color: Colors.white)),
                  trailing: ElevatedButton(
                    onPressed: () => _sendInvite(user['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                    ),
                    child: const Text("Zaproś"),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
