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
  TabController? _tabController;
  late final members = Supabase.instance.client
      .from('clubs_members')
      .select('user_id')
      .eq('club_id', clubData!['id']);
  late final clubMembersCount = (members as List).length;


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

    final members = await Supabase.instance.client
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);

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
      final membersRes = await supabase
          .from('clubs_members')
          .select('user_id')
          .eq('club_id', clubId);

      List members = membersRes as List<dynamic>;
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
    final club = await ClubController().getClubById(widget.clubId);
    if (club == null) {
      setState(() {
        clubData = null;
        isLoading = false;
      });
      return;
    }

    final motywId = club['motyw_id'] ?? 1;
    final motyw = await Supabase.instance.client
        .from('motywy_clubs')
        .select('*')
        .eq('id', motywId)
        .maybeSingle();

    _tabController = TabController(length: 3, vsync: this);

    setState(() {
      clubData = club;
      motywData = motyw;
      isLoading = false;
    });
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

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard("📖 Bio", clubData!['bio'] ?? 'Brak opisu'),
        const SizedBox(height: 12),
        _statCard("🔒 Typ klubu", clubData!['is_open'] ? "Otwarty" : "Zamknięty", Icons.lock),
        const SizedBox(height: 24),

        ElevatedButton.icon(
          icon: const Icon(Icons.exit_to_app, color: Colors.white),
          label: Text(
            clubData!['user_rola'] == 'Lider' && (clubMembersCount > 1)
                ? 'Opuść klub / Przekaż lidera'
                : (clubData!['user_rola'] == 'Lider' ? 'Usuń klub' : 'Opuść klub'),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          onPressed: _confirmLeave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

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
