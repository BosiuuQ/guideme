import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ClubEventsWidget extends StatefulWidget {
  final String clubId;

  const ClubEventsWidget({super.key, required this.clubId});

  @override
  State<ClubEventsWidget> createState() => _ClubEventsWidgetState();
}

class _ClubEventsWidgetState extends State<ClubEventsWidget> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> events = [];
  bool isLoading = true;
  bool canManage = false;

  final titleController = TextEditingController();
  final locationController = TextEditingController();
  final dateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchEvents();
    checkPermissions();
  }

  Future<void> fetchEvents() async {
    final result = await supabase
        .from('club_events')
        .select()
        .eq('club_id', widget.clubId)
        .order('event_date', ascending: true);

    setState(() {
      events = List<Map<String, dynamic>>.from(result);
      isLoading = false;
    });
  }

  Future<void> checkPermissions() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final result = await supabase
        .from('club_members')
        .select('role')
        .eq('club_id', widget.clubId)
        .eq('user_id', user.id)
        .maybeSingle();

    setState(() {
      canManage = result != null &&
          (result['role'] == 'Lider' || result['role'] == 'Zastepca');
    });
  }

  Future<void> createEvent() async {
    if (titleController.text.isEmpty ||
        locationController.text.isEmpty ||
        dateController.text.isEmpty) return;

    try {
      await supabase.from('club_events').insert({
        'club_id': widget.clubId,
        'title': titleController.text.trim(),
        'location': locationController.text.trim(),
        'event_date': dateController.text.trim(),
      });

      titleController.clear();
      locationController.clear();
      dateController.clear();

      Navigator.pop(context);
      fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas tworzenia zlotu: $e')),
      );
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await supabase.from('club_events').delete().eq('id', eventId);
      fetchEvents();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd podczas usuwania zlotu: $e')),
      );
    }
  }

  void _showAddEventDialog() {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text("Nowy zlot", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(titleController, "Tytuł"),
              _buildField(locationController, "Lokalizacja"),
              _buildField(dateController, "Data (np. 2025-05-12)"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: createEvent,
              child: const Text("Dodaj"),
            )
          ],
        );
      },
    );
  }

  Widget _buildField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[850],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final List<Widget> children = [];

    if (canManage) {
      children.add(Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: _showAddEventDialog,
          icon: const Icon(Icons.add),
          label: const Text("Utwórz zlot klubowy"),
        ),
      ));
    }

    if (events.isEmpty) {
      children.add(const Padding(
        padding: EdgeInsets.all(16),
        child: Text("Brak zlotów.", style: TextStyle(color: Colors.white70)),
      ));
    } else {
      children.addAll(events.map((event) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(event['title'],
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (canManage)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.redAccent),
                      onPressed: () => deleteEvent(event['id'].toString()),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text("📍 ${event['location']}",
                  style: TextStyle(color: Colors.grey[300])),
              const SizedBox(height: 2),
              Text("🗓️ ${event['event_date']}",
                  style: TextStyle(color: Colors.grey[400]))
            ],
          ),
        );
      }));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}
