import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:guide_me/features/wydarzenia/backend/events_backend.dart';
import 'package:guide_me/features/wydarzenia/models/event_model.dart';
import 'event_details_view.dart';

class EventsView extends StatefulWidget {
  const EventsView({super.key});

  @override
  State<EventsView> createState() => _EventsViewState();
}

class _EventsViewState extends State<EventsView> with TickerProviderStateMixin {
  final backend = EventsBackend();
  List<Event> events = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    loadEvents();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> loadEvents() async {
    final data = await backend.fetchEvents();
    setState(() => events = data);
  }

  @override
  Widget build(BuildContext context) {
    final officialEvents = events.where((e) => e.type == 'official').toList();
    final communityEvents = events.where((e) => e.type == 'community').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Wydarzenia i Zloty'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🏁 Oficjalne'),
            Tab(text: '🚗 Społeczność'),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: loadEvents,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildEventList(officialEvents),
            _buildEventList(communityEvents),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/addEvent'),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventList(List<Event> list) {
    if (list.isEmpty) {
      return const Center(child: Text('Brak wydarzeń 💤'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final event = list[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailsView(event: event)),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🖼️ Obrazek wydarzenia
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    event.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(height: 160, child: Center(child: Icon(Icons.broken_image))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, size: 16),
                          const SizedBox(width: 4),
                          Text(DateFormat('dd.MM.yyyy • HH:mm').format(event.startTime)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text(event.location)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.type == 'official' ? Colors.deepPurple : Colors.blueGrey,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          event.type == 'official' ? 'Oficjalne wydarzenie 🏁' : 'Zlot społeczności 🚗',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
