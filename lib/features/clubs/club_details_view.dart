
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubDetailsView extends StatefulWidget {
  final Map<String, dynamic> club;

  const ClubDetailsView({super.key, required this.club});

  @override
  State<ClubDetailsView> createState() => _ClubDetailsViewState();
}

class _ClubDetailsViewState extends State<ClubDetailsView> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> members = [];

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    setState(() { isLoading = true; members = []; });
    try {
      // Try to fetch members and join user info. Adjust relation name if necessary.
      final res = await supabase
          .from('clubs_members')
          .select('id, rola, user_id, users!fk_clubs_members_user(nickname, avatar, account_lvl)')
          .eq('club_id', widget.club['id']);
      if (res != null && res is List) {
        List<Map<String,dynamic>> list = [];
        for (final r in res) {
          final user = r['users'] ?? {};
          list.add({
            'id': r['id'],
            'user_id': r['user_id'],
            'rola': r['rola'],
            'nickname': user['nickname'] ?? '',
            'avatar': user['avatar'] ?? '',
            'account_lvl': user['account_lvl'] ?? 0,
          });
        }
        setState(() { members = list; isLoading = false; });
      } else {
        setState(() { members = []; isLoading = false; });
      }
    } catch (e) {
      debugPrint('fetchMembers error: $e');
      setState(() { members = []; isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF03121A);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.club['name'] ?? 'Szczegóły klubu'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // header
                  Row(
                    children: [
                      CircleAvatar(radius: 36, backgroundImage: NetworkImage(widget.club['logo_url'] ?? '')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(widget.club['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(widget.club['bio'] ?? '', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 18),
                  const Text('Członkowie', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  if (members.isEmpty) const Text('Brak członków', style: TextStyle(color: Colors.white70)) else ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_,__) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final m = members[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        leading: CircleAvatar(
                          backgroundImage: m['avatar'] != '' ? NetworkImage(m['avatar']) : null,
                          backgroundColor: Colors.white10,
                          child: (m['avatar']==null || m['avatar']=='') ? const Icon(Icons.person, color: Colors.white) : null,
                        ),
                        title: Text(m['nickname'] ?? '', style: const TextStyle(color: Colors.white)),
                        subtitle: Text('Lvl ${m['account_lvl'] ?? 0} – ${m['rola'] ?? ''}', style: const TextStyle(color: Colors.white70)),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
