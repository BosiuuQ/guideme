import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubsHomeView extends StatefulWidget {
  const ClubsHomeView({super.key});

  @override
  State<ClubsHomeView> createState() => _ClubsHomeViewState();
}

class _ClubsHomeViewState extends State<ClubsHomeView> {
  bool isLoading = true;
  bool isInClub = false;
  List<Map<String, dynamic>> invitations = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final clubResponse = await Supabase.instance.client
        .from('clubs_members')
        .select()
        .eq('user_id', userId)
        .limit(1)
        .maybeSingle();

    final invitationsResponse = await Supabase.instance.client
        .from('club_invitations')
        .select('id, club_id, clubs(name)')
        .eq('user_id', userId);

    if (!mounted) return;

    setState(() {
      isInClub = clubResponse != null;
      invitations = List<Map<String, dynamic>>.from(invitationsResponse);
      isLoading = false;
    });
  }

  Future<void> _acceptInvite(String inviteId, String clubId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final existingClub = await Supabase.instance.client
        .from('clubs_members')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (existingClub != null) return;

    await Supabase.instance.client.from('clubs_members').insert({
      'user_id': userId,
      'club_id': clubId,
      'rola': 'Czlonek',
    });

    await Supabase.instance.client
        .from('club_invitations')
        .delete()
        .eq('id', inviteId);

    _loadData();
  }

  Future<void> _rejectInvite(String inviteId) async {
    await Supabase.instance.client
        .from('club_invitations')
        .delete()
        .eq('id', inviteId);
    _loadData();
  }

  void _showInvitesDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text("Zaproszenia", style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          child: invitations.isEmpty
              ? const Text("Brak zaproszeń", style: TextStyle(color: Colors.white70))
              : ListView.separated(
                  shrinkWrap: true,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white24),
                  itemCount: invitations.length,
                  itemBuilder: (context, index) {
                    final invite = invitations[index];
                    final clubName = invite['clubs']?['name'] ?? 'Nieznany klub';
                    return ListTile(
                      title: Text(clubName, style: const TextStyle(color: Colors.white)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              await _acceptInvite(
                                invite['id'].toString(),
                                invite['club_id'].toString(),
                              );
                              if (mounted) Navigator.of(dialogContext).pop();
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              await _rejectInvite(invite['id'].toString());
                              if (mounted) Navigator.of(dialogContext).pop();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text("Zamknij", style: TextStyle(color: Colors.amber)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.groups_rounded, color: Colors.white),
            const SizedBox(width: 8),
            const Text("Kluby", style: TextStyle(fontSize: 24, color: Colors.white)),
            const Spacer(),
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: _showInvitesDialog,
                ),
                if (invitations.isNotEmpty)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        invitations.length.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Dołącz do klubu lub załóż własny.",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  _buildButton(
                    icon: Icons.search_rounded,
                    label: "Przeglądaj kluby",
                    color1: Colors.deepPurple,
                    color2: Colors.blueAccent,
                    onTap: () => GoRouter.of(context).push('/clubs/list'),
                  ),
                  const SizedBox(height: 16),
                  if (isInClub)
                    _buildButton(
                      icon: Icons.emoji_people_rounded,
                      label: "Mój klub",
                      color1: Colors.teal,
                      color2: Colors.green,
                      onTap: () => GoRouter.of(context).push('/clubs/my'),
                    )
                  else
                    _buildButton(
                      icon: Icons.add_circle_outline_rounded,
                      label: "Załóż klub",
                      color1: Colors.orange,
                      color2: Colors.deepOrangeAccent,
                      onTap: () async {
                        final result = await GoRouter.of(context).push('/clubs/create');
                        if (result == true && mounted) {
                          _loadData(); // odśwież po utworzeniu klubu
                        }
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color2.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
