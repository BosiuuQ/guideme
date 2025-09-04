import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/scheduler.dart';

// ... importy bez zmian

class PanelAdminView extends StatefulWidget {
  const PanelAdminView({super.key});

  @override
  State<PanelAdminView> createState() => _PanelAdminViewState();
}

class _PanelAdminViewState extends State<PanelAdminView> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;
  final List<String> categories = ['Widokowe', 'InstaGuide', 'Garaż', 'Profile'];
  Map<String, List<Map<String, dynamic>>> reports = {};
  String? role, nickname, avatarUrl;
  int userCount = 0;
  double totalKm = 0;
  int viewpointCount = 0;
  int instaPostCount = 0;
  int monthlyActiveUsers = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final prof = await supabase.from('users').select().eq('id', user.id).single();
    nickname = prof['nickname'];
    role = prof['rola'];
    avatarUrl = prof['avatar'];

    final users = await supabase.from('users').select('id');
    final km = await supabase.from('user_distance').select('total_km');
    final points = await supabase.from('punkty_widokowe').select('id');
    final posts = await supabase.from('instagram_posty').select('id');
    final activeUsers = await supabase
        .from('users')
        .select('id')
        .gte('last_online', DateTime.now().subtract(const Duration(days: 30)).toIso8601String());

    userCount = users.length;
    totalKm = km.fold(0.0, (sum, e) => sum + (e['total_km'] ?? 0));
    viewpointCount = points.length;
    instaPostCount = posts.length;
    monthlyActiveUsers = activeUsers.length;

    // pobierz zgłoszenia
   // Widokowe
reports['Widokowe'] = await supabase
    .from('punkty_widokowe_zgloszenia')
    .select('*, users(nickname)')
    .order('created_at', ascending: false);

// InstaGuide
reports['InstaGuide'] = await supabase
    .from('zgloszenia_ig')
    .select('*, users:reporter_user_id(nickname)')
    .order('created_at', ascending: false);

// Garaż
reports['Garaż'] = await supabase
    .from('zgloszenia_pojazdy')
    .select('*, users:reporter_id(nickname)')
    .order('created_at', ascending: false);

// Profile
reports['Profile'] = await supabase
    .from('zgloszenia_profile')
    .select('*, reporter:users!zgloszenia_profile_reporter_user_id_fkey(nickname), reported:users!zgloszenia_profile_reported_user_id_fkey(nickname)')
    .order('created_at', ascending: false);
    setState(() {});
  }

  String getRoleLabel(String? r) {
    switch (r) {
      case 'Admin':
        return 'Administrator GuideMe';
      case 'Mod':
        return 'Moderator GuideMe';
      case 'Ceo':
        return 'CEO GuideMe';
      default:
        return 'Użytkownik';
    }
  }

  Future<void> handleAction(String action, Map<String, dynamic> report, String category) async {
    final rolaText = getRoleLabel(role);
    final reporter = report['users']?['nickname'] ?? report['reporter']?['nickname'] ?? 'Nieznany';
    final jsonText = const JsonEncoder.withIndent('  ').convert(report);

    final embed = {
      "embeds": [
        {
          "title": "$rolaText $nickname ${action == 'accept' ? 'zaakceptował' : 'usunął'} zgłoszenie",
          "description": "**Kategoria:** $category\n**Zgłaszający:** $reporter\n**Zgłoszenie:** ```json\n$jsonText\n```",
          "color": action == 'accept' ? 65280 : 16711680
        }
      ]
    };

    await http.post(
      Uri.parse('https://discord.com/api/webhooks/1396547545794220234/7kCUZHBZAIL6tAdvzrve197kaJzY_B5vdQWxY0S5j1VN52Ks19v_Qqlo2IpvEb5i16dC'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(embed),
    );

    final tableMap = {
      'Widokowe': 'punkty_widokowe_zgloszenia',
      'InstaGuide': 'zgloszenia_ig',
      'Garaż': 'zgloszenia_pojazdy',
      'Profile': 'zgloszenia_profile',
    };

    await supabase.from(tableMap[category]!).delete().eq('id', report['id']);
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        title: const Text("Panel Moderatorów"),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 4,
      ),
      body: Column(
        children: [
          ListTile(
            leading: CircleAvatar(backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null, radius: 30),
            title: Text(nickname ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            subtitle: Text("Twoja ranga: ${getRoleLabel(role)}", style: const TextStyle(color: Colors.lightBlueAccent)),
          ),
          const Divider(color: Colors.grey, thickness: 0.5),
          const SizedBox(height: 8),
          const Text("📊 Statystyki Aplikacji", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text("Oficjalna Premiera: XX.XX.2025", style: TextStyle(color: Colors.grey)),
          Text("Wersja Aplikacji: 0.4.0", style: TextStyle(color: Colors.grey)),
          Text("Użytkowników: $userCount", style: TextStyle(color: Colors.white)),
          Text("Suma przejechanych km: ${totalKm.toStringAsFixed(1)} km", style: TextStyle(color: Colors.white)),
          Text("Punktów widokowych: $viewpointCount", style: TextStyle(color: Colors.white)),
          Text("Postów InstaGuide: $instaPostCount", style: TextStyle(color: Colors.white)),
          Text("Aktywnych miesięcznie: $monthlyActiveUsers", style: TextStyle(color: Colors.white)),
          const SizedBox(height: 16),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.cyanAccent,
            tabs: categories.map((e) => Tab(text: e)).toList(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: categories.map((cat) {
                final list = reports[cat] ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text("Brak zgłoszeń", style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final reason = r['reason'] ?? 'Brak powodu';
                    final nick = r['users']?['nickname'] ?? r['reporter']?['nickname'] ?? 'Nieznany';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1F1C2C), Color(0xFF928DAB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        title: Text(reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text("Zgłaszający: $nick", style: const TextStyle(color: Colors.white70)),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_red_eye, color: Colors.amberAccent),
                              onPressed: () {
                                // TODO: otwórz szczegóły obiektu
                              },
                              tooltip: "Zobacz",
                            ),
                            IconButton(
                              icon: const Icon(Icons.check_circle, color: Colors.greenAccent),
                              onPressed: () => handleAction("accept", r, cat),
                              tooltip: "Akceptuj",
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => handleAction("delete", r, cat),
                              tooltip: "Usuń",
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
            ),
          )
        ],
      ),
    );
  }
}