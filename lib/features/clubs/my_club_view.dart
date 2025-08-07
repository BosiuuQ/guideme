import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/features/clubs/club_chat_widget.dart';
import 'package:guide_me/features/clubs/club_members_widget.dart';
import 'package:guide_me/features/clubs/club_events_widget.dart';
import 'package:guide_me/features/clubs/club_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';

class MyClubView extends StatefulWidget {
  const MyClubView({super.key});

  @override
  State<MyClubView> createState() => _MyClubViewState();
}

class _MyClubViewState extends State<MyClubView> with TickerProviderStateMixin {
  Map<String, dynamic>? clubData;
  Map<String, dynamic>? motywData;
  bool isLoading = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadClubAndMotyw();
  }

  Future<void> _loadClubAndMotyw() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final club = await ClubController().getMyClub(userId);
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
      clubData = {
        ...club,
        'average_level': club['average_level'] ?? 0,
        'average_km': club['average_km'] ?? 0,
        'members': club['members'] ?? 0,
        'events_count': club['events_count'] ?? 0,
      };
      motywData = motyw;
      isLoading = false;
    });
  }

  Future<void> _leaveClub() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final rola = clubData?['user_rola'];
    final clubId = clubData?['id'];

    final members = await Supabase.instance.client
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);

    if (rola == 'Lider' && members.length == 1) {
      await Supabase.instance.client
          .from('clubs_members')
          .delete()
          .eq('club_id', clubId);

      await Supabase.instance.client
          .from('clubs')
          .delete()
          .eq('id', clubId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Klub został usunięty.")),
        );
        setState(() => clubData = null);
      }
    } else if (rola == 'Lider') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Lider nie może opuścić klubu bez przekazania roli."),
        ),
      );
    } else {
      await Supabase.instance.client
          .from('clubs_members')
          .delete()
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Opuściłeś klub.")),
        );
        setState(() => clubData = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || _tabController == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (clubData == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Nie należysz do żadnego klubu.",
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final tloUrl = motywData?['image_url'] ??
        'https://img.mobiles24.net/static/previews/downloads/default/331/P-651412-gQtRObcOWF-1.jpg';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.5),
        elevation: 0,
        title: Text(
          clubData!['name'],
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          if (clubData!['user_rola'] == 'Lider' || clubData!['user_rola'] == 'Zastepca') ...[
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => context.pushNamed('club-edit', extra: clubData),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.amber),
              tooltip: 'Zaproś do klubu',
              onPressed: () => context.pushNamed('club-invite', extra: clubData!['id']),
            ),
          ],
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'leave') _confirmLeave();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'leave',
                child: Text('🚪 Opuść klub'),
              ),
            ],
          ),
        ],
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

  void _confirmLeave() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final clubId = clubData?['id'];
    final rola = clubData?['user_rola'];

    final members = await Supabase.instance.client
        .from('clubs_members')
        .select('user_id')
        .eq('club_id', clubId);

    final bool isOnlyMember = members.length == 1 && rola == 'Lider';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(isOnlyMember ? 'Usunąć klub?' : 'Opuść klub?',
            style: const TextStyle(color: Colors.white)),
        content: Text(
          isOnlyMember
              ? 'Jesteś jedynym członkiem. Czy na pewno chcesz usunąć klub?'
              : 'Czy na pewno chcesz opuścić klub?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anuluj', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveClub();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(isOnlyMember ? 'Tak, usuń' : 'Tak, opuść'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _infoCard("\uD83D\uDCD6 Bio", clubData!['bio'] ?? 'Brak opisu'),
        const SizedBox(height: 12),
        const Text("\uD83D\uDCCA Statystyki klubu",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        _statCard("\uD83D\uDC65 Liczba członków", "${clubData!['members']} / 20", Icons.group),
        _statCard("\uD83D\uDD10 Typ klubu", clubData!['is_open'] ? "Otwarty" : "Zamknięty", Icons.lock_open),
        _statCard("\uD83D\uDCC6 Ranking Klubu", "w trakcie prac", Icons.calendar_today),
        _statCard("⭐ Średni poziom członków", "${clubData!['average_level']}", Icons.bar_chart),
        _statCard("\uD83D\uDEA3️ Średnia liczba km", "${clubData!['average_km']} km", Icons.directions_car),
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
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
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
          Icon(icon, color: Colors.amber, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsAndChat() {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        const Text("\uD83D\uDCC6 Zloty klubowe",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ClubEventsWidget(clubId: clubData!['id']),
        ),
        const SizedBox(height: 24),
        const Text("\uD83D\uDCAC Czat klubowy",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SizedBox(
          height: 400,
          child: ClubChatWidget(clubId: clubData!['id']),
        ),
      ],
    );
  }
}
