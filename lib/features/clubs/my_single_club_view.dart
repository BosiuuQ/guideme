import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/features/clubs/club_chat_widget.dart';
import 'package:guide_me/features/clubs/club_members_widget.dart';
import 'package:guide_me/features/clubs/club_events_widget.dart';
import 'package:guide_me/features/clubs/club_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class MySingleClubView extends StatefulWidget {
  final String clubId;
  const MySingleClubView({super.key, required this.clubId});

  @override
  State<MySingleClubView> createState() => _MySingleClubViewState();
}

class _MySingleClubViewState extends State<MySingleClubView> with TickerProviderStateMixin {
  Map<String, dynamic>? clubData;
  Map<String, dynamic>? motywData;
  bool isLoading = true;
  bool isLeader = false;
  TabController? _tabController;
  late final members = Supabase.instance.client
      .from('clubs_members')
      .select('user_id')
      .eq('club_id', clubData!['id']);
  late var clubMembersCount = (members as List).length;


  @override
  void initState() {
    super.initState();
    _loadClubAndMotyw();
  }

  void _confirmLeave() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final clubId = clubData?['id'];
    final rola = clubData?['user_rola'] ?? '';

    // Robust fetch of members that handles various supabase client behaviors
    final membersQuery = Supabase.instance.client
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);
    dynamic membersResValue;
    List<dynamic> members = [];
    try {
      // try calling execute() if available (some clients expose it)
      try {
        final execRes = await (membersQuery as dynamic).execute();
        membersResValue = execRes?.data ?? execRes;
      } catch (e) {
        // fallback: try awaiting the query directly
        try {
          final directRes = await membersQuery;
          membersResValue = (directRes is List) ? directRes : (directRes ?? []);
        } catch (e2) {
          membersResValue = [];
        }
      }
    } catch (e) {
      membersResValue = [];
    }
    if (membersResValue is List) {
      members = List<dynamic>.from(membersResValue);
    } else {
      // final fallback: empty list to avoid runtime cast errors
      members = <dynamic>[];
    }
final bool isOnlyMember = members.length == 1 && rola == 'Lider';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF03121A),
        title: Text(
          isOnlyMember ? 'Usunąć klub?' : 'Opuścić klub?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          isOnlyMember
              ? 'Jesteś jedynym członkiem tego klubu. Czy na pewno chcesz go usunąć?'
              : 'Czy na pewno chcesz opuścić ten klub?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _leaveClub();
            },
            child: Text(isOnlyMember ? 'Tak, usuń' : 'Tak, opuść'),
          ),
        ],
      ),
    );
  }

  Future<void> _leaveClub() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    final clubId = clubData?['id'];
    final rola = clubData?['user_rola'] ?? '';

    if (userId == null || clubId == null) return;

    try {
      // Pobierz aktualną listę członków
      // Robust fetch of members that handles various supabase client behaviors
    final membersQuery = supabase
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);
    dynamic membersResValue;
    List<dynamic> members = [];
    try {
      // try calling execute() if available (some clients expose it)
      try {
        final execRes = await (membersQuery as dynamic).execute();
        membersResValue = execRes?.data ?? execRes;
      } catch (e) {
        // fallback: try awaiting the query directly
        try {
          final directRes = await membersQuery;
          membersResValue = (directRes is List) ? directRes : (directRes ?? []);
        } catch (e2) {
          membersResValue = [];
        }
      }
    } catch (e) {
      membersResValue = [];
    }
    if (membersResValue is List) {
      members = List<dynamic>.from(membersResValue);
    } else {
      // final fallback: empty list to avoid runtime cast errors
      members = <dynamic>[];
    }
final int memberCount = members.length;

      if (rola == 'Lider') {
        if (memberCount == 1) {
          // Jedyny członek → usuń klub
          await supabase.from('clubs_members').delete().eq('club_id', clubId);
          await supabase.from('clubs').delete().eq('id', clubId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Klub został usunięty.')),
            );
            Navigator.pop(context); // Zamknij widok klubu
          }
        } else {
          // Lider przekazuje rolę losowemu członkowi i opuszcza klub
          // Wybieramy losowego członka innego niż lider
          final newLeader = members.firstWhere((m) => m['user_id'] != userId);
          await supabase
              .from('clubs_members')
              .update({'role': 'Lider'})
              .eq('user_id', newLeader['user_id'])
              .eq('club_id', clubId);

          // Usuń siebie z klubu
          await supabase
              .from('clubs_members')
              .delete()
              .eq('user_id', userId)
              .eq('club_id', clubId);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Opuszczono klub. Rola lidera została przekazana.')),
            );
            Navigator.pop(context);
          }
        }
      } else {
        // Zwykły członek usuwa tylko siebie
        await supabase
            .from('clubs_members')
            .delete()
            .eq('user_id', userId)
            .eq('club_id', clubId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opuszczono klub.')),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('Leave club error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wystąpił błąd. Spróbuj ponownie.')),
      );
    }
  }




  Future<void> _loadClubAndMotyw() async {
    final supabase = Supabase.instance.client;
    try {
      // Pobierz klub
      final clubRes = await supabase.from('clubs').select('*').eq('id', widget.clubId).maybeSingle();
      if (clubRes == null) {
        if (mounted) {
          setState(() {
            clubData = null;
            isLoading = false;
          });
        }
        return;
      }
      final Map<String, dynamic> club = Map<String, dynamic>.from(clubRes);

      // motyw
      final motywId = club['motyw_id'] ?? 1;
      final motywRes = await supabase.from('motywy_clubs').select('*').eq('id', motywId).maybeSingle();
      final motyw = motywRes != null ? Map<String, dynamic>.from(motywRes) : null;

      // Pobierz członków klubu
      final membersRes = await supabase.from('clubs_members').select('user_id, rola').eq('club_id', widget.clubId);
      List<Map<String, dynamic>> members = [];
      if (membersRes is List) {
        members = membersRes.map((e) => Map<String, dynamic>.from(e)).toList();
      }

      final membersCount = members.length;

      // Sprawdź rolę zalogowanego użytkownika
      final userId = supabase.auth.currentUser?.id;
      bool leaderFlag = false;
      if (userId != null) {
        final userMember = members.firstWhere(
              (m) => m['user_id'] == userId,
          orElse: () => {},
        );
        if (userMember.isNotEmpty) {
          final rola = userMember['rola']?.toString();
          if (rola == 'Lider') leaderFlag = true;
        }
      }

      if (mounted) {
        setState(() {
          clubData = club;
          motywData = motyw;
          clubMembersCount = membersCount;
          isLeader = leaderFlag;
          _tabController = TabController(length: 3, vsync: this);
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading club: $e');
      if (mounted) {
        setState(() {
          clubData = null;
          isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    if (isLoading || _tabController == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF03121A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (clubData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF03121A),
        body: Center(
          child: Text("Nie znaleziono danych klubu.",
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }




    final tloUrl = motywData?['image_url'] ??
        'https://img.mobiles24.net/static/previews/downloads/default/331/P-651412-gQtRObcOWF-1.jpg';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFF03121A).withOpacity(0.5),
        elevation: 0,
        title: Text(
          clubData!['name'] ?? '',
          style: const TextStyle(color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'ℹ️ Info'),
            Tab(text: '👥 Członkowie'),
            Tab(text: '💬 Zloty & Czat'),
          ],
        ),
      ),
      body: Stack(
        children: [
          Image.network(
            tloUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
          Container(color: Colors.black.withOpacity(0.4)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
          SafeArea(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                ClubMembersWidget(clubId: clubData!['id']),
                _buildEventsAndChat(),
              ],
            ),
          ),
        ],
      ),
    );
  }

void _confirmDelete() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final clubId = clubData?['id'];
    if (clubId == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF03121A),
        title: const Text('Usunąć klub?', style: TextStyle(color: Colors.white)),
        content: const Text('Czy na pewno chcesz usunąć ten klub? Operacja usunie klub dla wszystkich członków.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anuluj', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteClub();
            },
            child: const Text('Tak, usuń'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClub() async {
    final supabase = Supabase.instance.client;
    final clubId = clubData?['id'];
    if (clubId == null) return;
    try {
      // Usuń członków i sam klub
      await supabase.from('clubs_members').delete().eq('club_id', clubId);
      await supabase.from('clubs').delete().eq('id', clubId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Klub został usunięty.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Delete club error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Błąd podczas usuwania klubu.')),
        );
      }
    }
  }




Widget _buildInfoTab() {
    final memberCount = clubMembersCount;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard("📖 Bio", clubData!['bio'] ?? 'Brak opisu'),
        const SizedBox(height: 12),
        _statCard("🔒 Typ klubu", clubData!['is_open'] ? "Otwarty" : "Zamknięty", Icons.lock),
        const SizedBox(height: 24),

        // Buttons visible depending on role and member count:
        if (isLeader && memberCount == 1) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text('Usuń klub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _confirmDelete,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else if (isLeader && memberCount > 1) ...[
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Usuń klub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _confirmDelete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text('Opuść klub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  onPressed: _confirmLeave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ] else if (!isLeader && memberCount > 1) ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            label: const Text('Opuść klub', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: _confirmLeave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ] else ...[
          // Not leader and only member (edge case) -> no buttons
          const SizedBox.shrink(),
        ],

      ],
    );
  }
Widget _infoCard(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 6),
          Text(content,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text('$label: $value',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsAndChat() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SizedBox(height: 220, child: ClubEventsWidget(clubId: clubData!['id'])),
        const SizedBox(height: 24),
        SizedBox(height: 400, child: ClubChatWidget(clubId: clubData!['id'])),
      ],
    );
  }

}
