import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/core/constants/app_colors.dart';

class SearchUserView extends StatefulWidget {
  const SearchUserView({Key? key}) : super(key: key);

  @override
  State<SearchUserView> createState() => _SearchUserViewState();
}

class _SearchUserViewState extends State<SearchUserView> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty || query.length < 3) return;

    setState(() {
      _isLoading = true;
      _results = [];
    });

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, nickname, avatar, account_lvl')
          .ilike('nickname', '%$query%');

      if (response != null && response is List) {
        setState(() {
          _results = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd podczas wyszukiwania: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBlue,
      appBar: AppBar(
        backgroundColor: AppColors.darkBlue,
        title: TextField(
          controller: _controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Szukaj użytkownika...',
            hintStyle: TextStyle(color: Colors.white54),
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: Colors.white54),
          ),
          onChanged: _searchUsers,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty
              ? const Center(
                  child: Text("Brak wyników", style: TextStyle(color: Colors.white54)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      leading: CircleAvatar(
                        backgroundImage: user['avatar'] != null && user['avatar'].toString().isNotEmpty
                            ? NetworkImage(user['avatar'])
                            : null,
                        backgroundColor: Colors.white10,
                      ),
                      title: Text(user['nickname'] ?? 'Brak nicku',
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text("Poziom: ${user['account_lvl'] ?? 0}",
                          style: const TextStyle(color: Colors.white60)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white38, size: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Colors.white10,
                      onTap: () {
                        final userId = user['id'] as String;
                        context.pushNamed(
                          'userProfile',
                          pathParameters: {'userId': userId},
                        );
                      },
                    );
                  },
                ),
    );
  }
}
