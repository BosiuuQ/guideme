import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserSearchDelegate extends SearchDelegate {
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    if (query.isEmpty) return [];
    final response = await Supabase.instance.client
        .from('users')
        .select('id, nickname, avatar, account_lvl, last_online, rola')
        .ilike('nickname', '%$query%');

    if (response == null) return [];
    if (response is List) {
      return List<Map<String, dynamic>>.from(response);
    }
    return [];
  }

  bool _isOnline(String? lastOnline) {
    if (lastOnline == null) return false;
    final last = DateTime.tryParse(lastOnline);
    if (last == null) return false;
    return DateTime.now().difference(last).inMinutes < 5;
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      )
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _searchUsers(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Błąd: ${snapshot.error}"));
        }
        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text("Brak wyników."));
        }

        return ListView.builder(
          itemCount: results.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemBuilder: (context, index) {
            final user = results[index];
            final userId = user['id'] as String;
            final nickname = user['nickname'] ?? 'Nieznany';
            final avatar = user['avatar'] ?? '';
            final lvl = user['account_lvl']?.toString() ?? '0';
            final lastOnline = user['last_online'] as String?;
            final rola = user['rola'] ?? '';
            final isOnline = _isOnline(lastOnline);

            return ListTile(
              onTap: () {
                context.pushNamed(
                  'userProfile',
                  pathParameters: {'userId': userId},
                );
                close(context, null);
              },
              leading: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      nickname,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (rola == 'Premium') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber, width: 1),
                      ),
                      child: const Text(
                        "PREMIUM",
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Poziom: $lvl", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  Text(
                    isOnline ? "Online teraz" : "Offline",
                    style: TextStyle(
                      color: isOnline ? Colors.greenAccent : Colors.white30,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: Colors.white10,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              horizontalTitleGap: 12,
            );
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return const Center(child: Text("Wpisz nickname użytkownika..."));
    }
    return buildResults(context);
  }
}
