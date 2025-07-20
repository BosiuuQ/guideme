import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SpotDetailView extends StatefulWidget {
  final Map<String, dynamic> spot;

  const SpotDetailView({super.key, required this.spot});

  @override
  State<SpotDetailView> createState() => _SpotDetailViewState();
}

class _SpotDetailViewState extends State<SpotDetailView> {
  final supabase = Supabase.instance.client;
  bool _isJoined = false;
  bool _isAuthor = false;
  List<Map<String, dynamic>> _participantsProfiles = [];
  Map<String, dynamic>? _authorProfile;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final spotId = widget.spot['id'];
    final authorId = widget.spot['autor'];

    _isAuthor = userId == authorId;

    // Pobierz uczestników
    final uczestnicyRes = await supabase
        .from('spoty_uczestnicy')
        .select('user_id')
        .eq('spot_id', spotId);

    final userIds = List<String>.from(uczestnicyRes.map((u) => u['user_id']));
    _isJoined = userIds.contains(userId);

    // Pobierz dane profili uczestników
    if (userIds.isNotEmpty) {
      final profiles = await supabase
          .from('users')
          .select('id, nickname, avatar, account_lvl')
          .inFilter('id', userIds);
      _participantsProfiles = List<Map<String, dynamic>>.from(profiles);
    }

    // Pobierz dane autora
    if (authorId != null && authorId is String) {
      final profile = await supabase
          .from('users')
          .select('nickname, avatar')
          .eq('id', authorId)
          .maybeSingle();

      _authorProfile = profile;
    }

    setState(() {});
  }

  Future<void> _toggleJoin() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final spotId = widget.spot['id'];

    try {
      if (_isJoined) {
        await supabase
            .from('spoty_uczestnicy')
            .delete()
            .match({'spot_id': spotId, 'user_id': userId});
      } else {
        await supabase.from('spoty_uczestnicy').upsert({
          'spot_id': spotId,
          'user_id': userId,
          'dolaczono_at': DateTime.now().toIso8601String(),
        });
      }

      await _loadData();
    } catch (e) {
      debugPrint("\u274c Toggle join error: $e");
    }
  }

  Future<void> _kickUser(String userId) async {
    final spotId = widget.spot['id'];

    await supabase
        .from('spoty_uczestnicy')
        .delete()
        .match({'spot_id': spotId, 'user_id': userId});

    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final spot = widget.spot;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0F1C),
      appBar: AppBar(
        title: Text(spot['tytul'] ?? 'Spot', style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              spot['zdjecie_url'] ?? '',
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Image.asset('assets/images/nightspot.jpg'),
            ),
          ),
          const SizedBox(height: 16),
          Text(spot['opis'] ?? '', style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          _infoRow(Icons.schedule, "${spot['data']} | czas: ${spot['czas_trwania'] ?? '-'}"),
          _infoRow(Icons.location_pin, spot['lokalizacja']),
          _infoRow(Icons.category, "Typ: ${spot['typ'] ?? '-'}"),
          _infoRow(Icons.visibility, "Widoczność: ${spot['widocznosc'] ?? '-'}"),
          _infoRow(Icons.person, "Autor: ${_authorProfile?['nickname'] ?? 'Nieznany'}"),

          const SizedBox(height: 16),

          if (spot['zasady'] != null && spot['zasady'].toString().trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.menu_book_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(spot['zasady'], style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _toggleJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isJoined ? Colors.redAccent : Colors.cyanAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(_isJoined ? "Opuść wydarzenie" : "\u2713 Dołącz do wydarzenia"),
          ),
          const SizedBox(height: 24),

          Text("Uczestnicy (${_participantsProfiles.length})", style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 8),
          ..._participantsProfiles.map((u) => ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(u['avatar'] ?? ''),
                  backgroundColor: Colors.grey,
                ),
                title: Text(u['nickname'] ?? 'Nieznany', style: const TextStyle(color: Colors.white)),
                subtitle: Text("Poziom: ${u['account_lvl'] ?? '-'}", style: const TextStyle(color: Colors.white70)),
                trailing: _isAuthor && u['id'] != supabase.auth.currentUser?.id
                    ? IconButton(
                        icon: const Icon(Icons.remove_circle, color: Colors.redAccent),
                        onPressed: () => _kickUser(u['id']),
                      )
                    : null,
              )),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
