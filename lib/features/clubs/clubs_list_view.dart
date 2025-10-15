import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/clubs/club_preview_widget.dart';
import 'package:guide_me/features/clubs/club_full_view.dart';

class ClubsListView extends StatefulWidget {
  const ClubsListView({super.key});

  @override
  State<ClubsListView> createState() => _ClubsListViewState();
}

class _ClubsListViewState extends State<ClubsListView> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> clubs = [];
  bool isLoading = true;
  String? myClubId;

  @override
  void initState() {
    super.initState();
    fetchClubs();
    fetchMyClub();
  }

  Future<void> fetchMyClub() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final clubMember = await supabase
        .from('clubs_members')
        .select('club_id')
        .eq('user_id', userId)
        .maybeSingle();

    if (mounted) {
      setState(() {
        myClubId = clubMember?['club_id'];
      });
    }
  }

  Future<void> fetchClubs() async {
    try {
          dynamic responseValue;
    List<dynamic> response = [];
    try {
      // try execute() if available
      try {
        final execRes = await ( supabase.from('clubs').select() as dynamic).execute();
        responseValue = execRes?.data ?? execRes;
      } catch (e) {
        // fallback: await directly
        try {
          final direct = await supabase.from('clubs').select();
          responseValue = (direct is List) ? direct : (direct ?? []);
        } catch (e2) {
          responseValue = [];
        }
      }
    } catch (e) { responseValue = []; }
    if (responseValue is List) {
      response = List<dynamic>.from(responseValue);
    } else {
      response = <dynamic>[];
    }

      final List data = (response is List) ? List<dynamic>.from(response) : ( (response ?? []) as List<dynamic> );
      setState(() {
        clubs = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      debugPrint('fetchClubs error: $e');
    }
  }

Future<void> joinClub(String clubId) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('clubs_members').insert({
      'user_id': userId,
      'club_id': clubId,
      'rola': 'Czlonek',
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dołączono do klubu!'))
      );
      fetchMyClub();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03121A),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : ListView.builder(
              itemCount: clubs.length,
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final club = clubs[index];
                final isOpen = club['is_open'] == true;
                final isMember = myClubId == club['id'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF062029),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    onTap: () => showClubPreview(context, club),
                    leading: CircleAvatar(
                      radius: 30,
                      backgroundImage: NetworkImage(club['logo_url'] ?? ''),
                    ),
                    title: Text(club['name'],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(club['bio'] ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isOpen ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                              color: isOpen ? Colors.greenAccent : Colors.redAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                isOpen ? "Otwarty" : "Zamknięty",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isOpen ? Colors.greenAccent : Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                    trailing: isMember
                        ? const Icon(Icons.check_circle, color: Colors.amber)
                        : isOpen
                            ? ElevatedButton(
                                onPressed: () => joinClub(club['id']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.deepPurpleAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text("Dołącz", style: TextStyle(color: Colors.white)),
                              )
                            : Tooltip(
                                message: "Do tego klubu można dołączyć tylko poprzez zaproszenie",
                                child: ElevatedButton(
                                  onPressed: null,
                                  style: ElevatedButton.styleFrom(
                                    disabledBackgroundColor: Colors.grey.shade700,
                                  ),
                                  child: const Text("Zablokowany",
                                      style: TextStyle(color: Colors.white54)),
                                ),
                              ),
                  ),
                );
              },
            ),
    );
  }
}
