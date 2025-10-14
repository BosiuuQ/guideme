import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/clubs/club_preview_widget.dart';

import 'my_single_club_view.dart';

class MyClubView extends StatefulWidget {
  const MyClubView({super.key});

  @override
  State<MyClubView> createState() => _MyClubViewState();
}

class _MyClubViewState extends State<MyClubView> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<Map<String, dynamic>> myClubs = [];

  @override
  void initState() {
    super.initState();
    fetchMyClubs();
  }

  Future<void> fetchMyClubs() async {
    setState(() {
      isLoading = true;
      myClubs = [];
    });
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        isLoading = false;
        myClubs = [];
      });
      return;
    }
    try {
      final members = await supabase.from('clubs_members').select('club_id').eq('user_id', userId);
      if (members == null || members is! List || members.isEmpty) {
        setState(() {
          myClubs = [];
          isLoading = false;
        });
        return;
      }
      List<Map<String, dynamic>> clubs = [];
      for (final m in members) {
        final cid = m['club_id'];
        final club = await supabase.from('clubs').select().eq('id', cid).maybeSingle();
        if (club != null) {
          clubs.add(Map<String, dynamic>.from(club));
        }
      }
      setState(() {
        myClubs = clubs;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('fetchMyClubs error: $e');
      setState(() {
        myClubs = [];
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF03121A);
    if (isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (myClubs.isEmpty) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false),
        body: const Center(child: Text('Nie należysz do żadnego klubu.', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, automaticallyImplyLeading: false),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: myClubs.length,
        itemBuilder: (context, index) {
          final club = myClubs[index];
          final isOpen = club['is_open'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF062029),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(radius: 28, backgroundImage: NetworkImage(club['logo_url'] ?? '')),
              title: Text(club['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(club['bio'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded, color: isOpen ? Colors.greenAccent : Colors.redAccent, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(isOpen ? 'Otwarty' : 'Zamknięty', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isOpen ? Colors.greenAccent : Colors.redAccent))),
                    ],
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right, color: Colors.white70),
              onTap: () {
                final clubId = club['id'].toString();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MySingleClubView(clubId: clubId)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
