import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class PanelAdminView extends StatefulWidget {
  const PanelAdminView({super.key});

  @override
  State<PanelAdminView> createState() => _PanelAdminViewState();
}

class _PanelAdminViewState extends State<PanelAdminView>
    with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;

  late TabController _tabController;
  final List<String> categories = ['Widokowe', 'InstaGuide', 'Garaż', 'Profile'];

  final Map<String, List<Map<String, dynamic>>> _raw = {
    'Widokowe': [],
    'InstaGuide': [],
    'Garaż': [],
    'Profile': [],
  };

  final Map<String, List<Map<String, dynamic>>> _reports = {
    'Widokowe': [],
    'InstaGuide': [],
    'Garaż': [],
    'Profile': [],
  };

  String? role, nickname, avatarUrl;
  int userCount = 0;
  double totalKm = 0;
  int viewpointCount = 0;
  int instaPostCount = 0;

  int dailyActiveUsers = 0;
  int weeklyActiveUsers = 0;
  int monthlyActiveUsers = 0;

  bool _loading = true;
  String? _error;
  String _search = '';
  bool _sortNewest = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: categories.length, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = supabase.auth.currentUser;
      if (me == null) throw Exception('Brak zalogowanego użytkownika.');

      final prof = await supabase.from('users').select().eq('id', me.id).single();
      nickname = prof['nickname'];
      role = prof['rola'];
      avatarUrl = prof['avatar'];

      final users = await supabase.from('users').select('id');
      final km = await supabase.from('user_distance').select('total_km');
      final points = await supabase.from('punkty_widokowe').select('id');
      final posts = await supabase.from('instagram_posty').select('id');

      userCount = (users as List).length;
      totalKm = (km as List)
          .map((e) => (e['total_km'] ?? 0).toString())
          .map((s) => double.tryParse(s) ?? 0.0)
          .fold(0.0, (a, b) => a + b);
      viewpointCount = (points as List).length;
      instaPostCount = (posts as List).length;

      final nowUtc = DateTime.now().toUtc();
      final todayStart = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day);
      final weekAgo = nowUtc.subtract(const Duration(days: 7));
      final monthAgo = nowUtc.subtract(const Duration(days: 30));

      dailyActiveUsers = (await supabase
              .from('users')
              .select('id')
              .gte('last_online', todayStart.toIso8601String()) as List)
          .length;

      weeklyActiveUsers = (await supabase
              .from('users')
              .select('id')
              .gte('last_online', weekAgo.toIso8601String()) as List)
          .length;

      monthlyActiveUsers = (await supabase
              .from('users')
              .select('id')
              .gte('last_online', monthAgo.toIso8601String()) as List)
          .length;

      await _fetchReportsAndEnrich();
    } catch (e) {
      _error = 'Błąd ładowania: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchReportsAndEnrich() async {
    _raw['Widokowe'] = List<Map<String, dynamic>>.from(
      await supabase
          .from('punkty_widokowe_zgloszenia')
          .select('*')
          .order('created_at', ascending: !_sortNewest) as List,
    );

    _raw['InstaGuide'] = List<Map<String, dynamic>>.from(
      await supabase
          .from('zgloszenia_ig')
          .select('*')
          .order('created_at', ascending: !_sortNewest) as List,
    );

    _raw['Garaż'] = List<Map<String, dynamic>>.from(
      await supabase
          .from('zgloszenia_pojazdy')
          .select('*')
          .order('created_at', ascending: !_sortNewest) as List,
    );

    _raw['Profile'] = List<Map<String, dynamic>>.from(
      await supabase
          .from('zgloszenia_profile')
          .select('*')
          .order('created_at', ascending: !_sortNewest) as List,
    );

    final ids = <String>{};

    String? _idOfReporter(Map<String, dynamic> r) {
      final any = r['reporter_user_id'] ??
          r['reporter_id'] ??
          r['user_id'] ??
          r['reported_by'];
      return any?.toString();
    }

    for (final r in _raw['Widokowe']!) {
      final id = _idOfReporter(r);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    for (final r in _raw['InstaGuide']!) {
      final id = _idOfReporter(r);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    for (final r in _raw['Garaż']!) {
      final id = _idOfReporter(r);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    for (final r in _raw['Profile']!) {
      final rep = _idOfReporter(r);
      final reported = r['reported_user_id']?.toString();
      if (rep != null && rep.isNotEmpty) ids.add(rep);
      if (reported != null && reported.isNotEmpty) ids.add(reported);
    }

    final usersById = await _fetchUsersMap(ids);

    Map<String, dynamic> _withReporter(Map<String, dynamic> r) {
      final m = Map<String, dynamic>.from(r);
      final rep = _idOfReporter(r);
      if (rep != null) m['reporter'] = usersById[rep];
      return m;
    }

    _reports['Widokowe'] =
        _raw['Widokowe']!.map((e) => _withReporter(e)).toList();
    _reports['InstaGuide'] =
        _raw['InstaGuide']!.map((e) => _withReporter(e)).toList();
    _reports['Garaż'] = _raw['Garaż']!.map((e) => _withReporter(e)).toList();
    _reports['Profile'] = _raw['Profile']!.map((e) {
      final m = _withReporter(e);
      final reported = e['reported_user_id']?.toString();
      if (reported != null) m['reported'] = usersById[reported];
      return m;
    }).toList();

    setState(() {});
  }

  Future<Map<String, Map<String, dynamic>>> _fetchUsersMap(
      Set<String> ids) async {
    final map = <String, Map<String, dynamic>>{};
    if (ids.isEmpty) return map;

    final inList = '(${ids.join(',')})'; // UUID bez cudzysłowów
    final rows = await supabase
        .from('users')
        .select('id, nickname, avatar')
        .filter('id', 'in', inList);

    for (final u in rows as List) {
      final m = Map<String, dynamic>.from(u as Map);
      map[m['id'].toString()] = m;
    }
    return map;
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

  List<Map<String, dynamic>> _filtered(String cat) {
    final list = _reports[cat] ?? [];
    if (_search.trim().isEmpty) return list;
    final q = _search.toLowerCase();
    return list.where((r) {
      final reason = (r['reason'] ?? '').toString().toLowerCase();
      final details = (r['details'] ?? '').toString().toLowerCase();
      final reporter = (r['reporter']?['nickname'] ?? '').toString().toLowerCase();
      final reported = (r['reported']?['nickname'] ?? '').toString().toLowerCase();
      return reason.contains(q) ||
          details.contains(q) ||
          reporter.contains(q) ||
          reported.contains(q);
    }).toList();
  }

  Future<void> _handleAction(
      String action, Map<String, dynamic> report, String category) async {
    try {
      final rolaText = getRoleLabel(role);
      final reporterNick =
          report['reporter']?['nickname'] ?? 'Nieznany';
      final jsonText =
          const JsonEncoder.withIndent('  ').convert(report);

      final embed = {
        "embeds": [
          {
            "title":
                "$rolaText $nickname ${action == 'accept' ? 'zaakceptował' : 'usunął'} zgłoszenie",
            "description":
                "**Kategoria:** $category\n**Zgłaszający:** $reporterNick\n**Zgłoszenie:** ```json\n$jsonText\n```",
            "color": action == 'accept' ? 65280 : 16711680
          }
        ]
      };

      await http.post(
        Uri.parse(
            'https://discord.com/api/webhooks/1396547545794220234/7kCUZHBZAIL6tAdvzrve197kaJzY_B5vdQWxY0S5j1VN52Ks19v_Qqlo2IpvEb5i16dC'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(embed),
      );
    } catch (_) {}

    final table = {
      'Widokowe': 'punkty_widokowe_zgloszenia',
      'InstaGuide': 'zgloszenia_ig',
      'Garaż': 'zgloszenia_pojazdy',
      'Profile': 'zgloszenia_profile',
    }[category]!;

    await supabase.from(table).delete().eq('id', report['id']);
    await _fetchReportsAndEnrich();
  }

  void _showDetails(String category, Map<String, dynamic> r) {
    final createdAt =
        DateTime.tryParse(r['created_at']?.toString() ?? '')?.toLocal();
    final reporter = r['reporter']?['nickname'] ?? 'Nieznany';
    final targetId = (r['target_id'] ??
            r['viewpoint_id'] ??
            r['vehicle_id'] ??
            r['reported_item_id'] ??
            r['item_id'])
        ?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF12121A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.report, color: Colors.amberAccent),
                    const SizedBox(width: 8),
                    const Text(
                      'Szczegóły zgłoszenia',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _kv('Kategoria', category),
                const SizedBox(height: 8),
                _kv('Powód', r['reason']?.toString() ?? '-'),
                const SizedBox(height: 8),
                _kv('Opis', r['details']?.toString() ?? '-'),
                const SizedBox(height: 8),
                _kv('Zgłaszający', reporter),
                if (r['reported'] != null) ...[
                  const SizedBox(height: 8),
                  _kv('Zgłoszony profil',
                      r['reported']?['nickname']?.toString() ?? '-'),
                ],
                const SizedBox(height: 8),
                _kv('ID obiektu', targetId ?? '-'),
                const SizedBox(height: 8),
                _kv('Data',
                    createdAt != null ? createdAt.toString() : '-'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.remove_red_eye),
                        label: const Text('Zobacz obiekt'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.greenAccent[400]),
                        onPressed: () {
                          Navigator.pop(context);
                          _handleAction('accept', r, category);
                        },
                        icon: const Icon(Icons.check_circle,
                            color: Colors.black),
                        label: const Text('Akceptuj',
                            style: TextStyle(color: Colors.black)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent),
                    onPressed: () {
                      Navigator.pop(context);
                      _handleAction('delete', r, category);
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text('Usuń'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(k,
              style: const TextStyle(
                  color: Colors.white70, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(v, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.cyanAccent),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Future<void> _onRefresh() async => _loadAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D14),
      appBar: AppBar(
        title: const Text("Panel Moderatorów"),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 4,
        actions: [
          IconButton(
            tooltip: _sortNewest ? 'Sortuj: najstarsze' : 'Sortuj: najnowsze',
            icon: Icon(_sortNewest ? Icons.south : Icons.north),
            onPressed: () async {
              setState(() => _sortNewest = !_sortNewest);
              await _fetchReportsAndEnrich();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                          radius: 26,
                          child:
                              avatarUrl == null ? const Icon(Icons.person) : null,
                        ),
                        title: Text(nickname ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text("Twoja ranga: ${getRoleLabel(role)}",
                            style:
                                const TextStyle(color: Colors.lightBlueAccent)),
                      ),
                      const Divider(color: Colors.white10, thickness: 0.5),

                      const SizedBox(height: 8),
                      const Text("📊 Statystyki Aplikacji",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _statChip(Icons.people_alt, 'Użytkownicy',
                                '$userCount'),
                            _statChip(Icons.map, 'Punktów widokowych',
                                '$viewpointCount'),
                            _statChip(Icons.photo_library, 'Postów IG',
                                '$instaPostCount'),
                            _statChip(Icons.route, 'Suma km',
                                '${totalKm.toStringAsFixed(1)}'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --- aktywni: horizontal scroll (zamiast 3x Expanded w Row) ---
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _statChip(Icons.today, 'Aktywni dziś',
                                '$dailyActiveUsers'),
                            _statChip(Icons.calendar_view_week, 'Aktywni 7d',
                                '$weeklyActiveUsers'),
                            _statChip(Icons.calendar_month, 'Aktywni 30d',
                                '$monthlyActiveUsers'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12.0),
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText:
                                'Szukaj w zgłoszeniach (powód/opis/nick)...',
                            filled: true,
                            fillColor: const Color(0xFF1A1A2E),
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.white12),
                            ),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),

                      TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        labelColor: Colors.cyanAccent,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: Colors.cyanAccent,
                        tabs: categories
                            .map((e) =>
                                Tab(text: '$e (${(_reports[e] ?? []).length})'))
                            .toList(),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: categories.map((cat) {
                            final list = _filtered(cat);
                            if (list.isEmpty) {
                              return const Center(
                                  child: Text('Brak zgłoszeń',
                                      style: TextStyle(color: Colors.grey)));
                            }
                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: list.length,
                              itemBuilder: (_, i) {
                                final r = list[i];
                                final reason =
                                    r['reason']?.toString() ?? 'Brak powodu';
                                final nick = r['reporter']?['nickname'] ??
                                    'Nieznany';
                                final createdAt = DateTime.tryParse(
                                        r['created_at']?.toString() ?? '')
                                    ?.toLocal();

                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF1F1C2C),
                                        Color(0xFF928DAB)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 12),
                                    title: Text(reason,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                      "Zgłaszający: $nick"
                                      "${createdAt != null ? " • ${createdAt.toString().substring(0, 16)}" : ""}",
                                      style: const TextStyle(
                                          color: Colors.white70),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _showDetails(cat, r),
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.remove_red_eye,
                                              color: Colors.amberAccent),
                                          onPressed: () =>
                                              _showDetails(cat, r),
                                          tooltip: 'Szczegóły',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.check_circle,
                                              color: Colors.greenAccent),
                                          onPressed: () => _handleAction(
                                              'accept', r, cat),
                                          tooltip: 'Akceptuj',
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete,
                                              color: Colors.redAccent),
                                          onPressed: () => _handleAction(
                                              'delete', r, cat),
                                          tooltip: 'Usuń',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
