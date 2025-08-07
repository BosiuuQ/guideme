import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:guide_me/features/wydarzenia/models/event_model.dart';

class EventDetailsView extends StatefulWidget {
  final Event event;

  const EventDetailsView({super.key, required this.event});

  @override
  State<EventDetailsView> createState() => _EventDetailsViewState();
}

class _EventDetailsViewState extends State<EventDetailsView> {
  final supabase = Supabase.instance.client;
  bool isJoined = false;
  List<Map<String, dynamic>> participants = [];
  String? creatorId;

  @override
  void initState() {
    super.initState();
    creatorId = widget.event.creatorId;
    loadParticipants();
  }

  Future<void> loadParticipants() async {
    final currentUserId = supabase.auth.currentUser?.id;

    final response = await supabase
        .from('event_participants')
        .select('user_id, users(nickname, avatar)')
        .eq('event_id', widget.event.id);

    final fetched = List<Map<String, dynamic>>.from(response);

    // 🔝 Sortuj – organizator na górze
    fetched.sort((a, b) {
      if (a['user_id'] == creatorId) return -1;
      if (b['user_id'] == creatorId) return 1;
      return 0;
    });

    setState(() {
      participants = fetched;
      isJoined = participants.any((p) => p['user_id'] == currentUserId);
    });
  }

  Future<void> toggleJoin() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final existing = await supabase
        .from('event_participants')
        .select()
        .eq('event_id', widget.event.id)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await supabase.from('event_participants').delete().eq('id', existing['id']);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚪 Opuściłeś wydarzenie')),
      );
    } else {
      await supabase.from('event_participants').insert({
        'event_id': widget.event.id,
        'user_id': userId,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Dołączyłeś do wydarzenia!')),
      );
    }

    await loadParticipants();
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      appBar: AppBar(title: Text('📅 ${event.title}')),
      body: ListView(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.network(
              event.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(
                height: 200,
                child: Center(child: Icon(Icons.broken_image, size: 48)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 20),
                    const SizedBox(width: 6),
                    Text(DateFormat('dd.MM.yyyy • HH:mm').format(event.startTime)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 20),
                    const SizedBox(width: 6),
                    Expanded(child: Text(event.location, style: const TextStyle(fontSize: 16))),
                  ],
                ),
                const SizedBox(height: 12),
                Text(event.description, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 24),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isJoined
                      ? Container(
                          key: const ValueKey('joined'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 10),
                              const Text(
                                'Dołączyłeś do wydarzenia',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: toggleJoin,
                                child: const Text('Opuść', style: TextStyle(color: Colors.red)),
                              )
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          key: const ValueKey('not_joined'),
                          icon: const Icon(Icons.event_available),
                          label: const Text('Dołącz do wydarzenia'),
                          onPressed: toggleJoin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 30),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '👥 Uczestnicy',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${participants.length} uczestników',
                      style: TextStyle(color: Colors.grey[500]),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                if (participants.isEmpty)
                  const Text('Brak uczestników 😢')
                else
                  Column(
                    children: participants.map((p) {
                      final user = p['users'];
                      final userId = p['user_id'];
                      final nickname = user['nickname'] ?? 'Użytkownik';
                      final avatar = user['avatar'] ??
                          'https://cdn-icons-png.flaticon.com/512/149/149071.png';

                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundImage: NetworkImage(avatar),
                          radius: 24,
                        ),
                        title: Row(
                          children: [
                            Text(nickname),
                            if (userId == creatorId) ...[
                              const SizedBox(width: 6),
                              const Text(
                                '👑 Organizator',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ]
                          ],
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          if (userId != null) {
                            context.pushNamed('userProfile', pathParameters: {
                              'userId': userId,
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
