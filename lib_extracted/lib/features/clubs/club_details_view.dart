import 'dart:ui';
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

  List<Map<String, dynamic>> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchMembers();
  }

  Future<void> fetchMembers() async {
    final response = await supabase
        .from('club_members')
        .select('role, users(nickname, avatar, account_lvl)')
        .eq('club_id', widget.club['id']);

    setState(() {
      members = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final club = widget.club;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Szczegóły klubu", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Tło z blur i ciemnym overlayem
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                  "https://wallpapers.com/images/hd/gang-pictures-i2z8fn6lsh9v85uv.jpg",
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.75)),
          ),
          // Zawartość
          ListView(
            padding: const EdgeInsets.only(top: kToolbarHeight + 24, bottom: 32),
            children: [
              _buildHeader(club),
              if (club['bio'] != null && club['bio'].toString().trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Text(
                    club['bio'],
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              _buildStats(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text("Członkowie", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (isLoading)
                const Center(child: CircularProgressIndicator())
              else if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text("Brak członków.", style: TextStyle(color: Colors.white70)),
                )
              else
                ...members.map((member) {
                  final user = member['users'];
                  final avatar = user['avatar'];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    leading: CircleAvatar(
                      backgroundColor: Colors.white10,
                      backgroundImage: avatar != null && avatar != ""
                          ? NetworkImage(avatar)
                          : null,
                      child: avatar == null || avatar == ""
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                    ),
                    title: Text(user['nickname'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      "Poziom ${user['account_lvl']}",
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Text(
                      member['role'],
                      style: TextStyle(
                        color: member['role'] == 'Lider'
                            ? Colors.amber
                            : member['role'] == 'Zastępca'
                                ? Colors.blueAccent
                                : Colors.white54,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Map club) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900]!.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white12,
              child: Icon(Icons.flag, color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(club['name'],
                      style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    if (members.isEmpty) return const SizedBox();

    final totalLevel = members.fold<int>(
      0,
      (sum, m) => sum + ((m['users']['account_lvl'] ?? 0) as num).toInt(),
    );
    final avgLvl = (totalLevel / members.length).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _statRow("Liczba członków", "${members.length}"),
            _statRow("Średni poziom", "$avgLvl"),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white)),
          Text(value, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
