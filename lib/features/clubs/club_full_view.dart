
import 'package:flutter/material.dart';
import 'package:guide_me/features/clubs/club_members_widget.dart';
import 'package:guide_me/features/clubs/club_chat_widget.dart';
import 'package:guide_me/features/clubs/club_events_widget.dart';
import 'package:guide_me/features/clubs/club_controller.dart';

class ClubFullView extends StatefulWidget {
  final Map<String,dynamic> club;
  const ClubFullView({super.key, required this.club});

  @override
  State<ClubFullView> createState() => _ClubFullViewState();
}

class _ClubFullViewState extends State<ClubFullView> with TickerProviderStateMixin {
  late TabController _tabController;
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF03121A);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(widget.club['name'] ?? 'Klub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Info'),
            Tab(text: 'Członkowie'),
            Tab(text: 'Wydarzenia'),
            Tab(text: 'Czat'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Info
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(widget.club['bio'] ?? '', style: const TextStyle(color: Colors.white70)),
          ),
          // Members
          ClubMembersWidget(clubId: widget.club['id'].toString()),
          // Events
          ClubEventsWidget(clubId: widget.club['id'].toString()),
          // Chat
          ClubChatWidget(clubId: widget.club['id'].toString()),
        ],
      ),
    );
  }
}
