import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/settings/settings_backend.dart';
import 'package:guide_me/features/settings/presentation/views/pdftermsview.dart'; // ← dodany import

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await SettingsBackend.getUserProfile();
    if (!mounted) return;
    setState(() {
      _profile = data;
      _loading = false;
    });
  }

  Future<void> _changeAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final file = File(picked.path);
      await SettingsBackend.updateAvatar(file);
      await _loadProfile();
    }
  }

  Future<void> _changeNickname() async {
    final controller = TextEditingController(text: _profile['nickname'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zmień nick"),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Anuluj")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Zapisz")),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await SettingsBackend.updateNickname(result.trim());
      await _loadProfile();
    }
  }

  Future<void> _changeBio() async {
    final controller = TextEditingController(text: _profile['description'] ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Zmień bio"),
        content: TextField(controller: controller, maxLines: 4),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Anuluj")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Zapisz")),
        ],
      ),
    );
    if (result != null) {
      await SettingsBackend.updateBio(result.trim());
      await _loadProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _profile['avatar'] as String? ?? "";
    final nickname = _profile['nickname'] as String? ?? "Brak nicku";
    final description = _profile['description'] as String? ?? "Brak opisu";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ustawienia"),
        backgroundColor: const Color(0xFF101935),
        actions: [
          IconButton(
            onPressed: () => context.pop(true),
            icon: const Icon(Icons.close),
          )
        ],
      ),
      backgroundColor: const Color(0xFF101935),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl.isEmpty
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text("Nick", style: TextStyle(color: Colors.white70)),
                  subtitle: Text(nickname, style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _changeNickname,
                  ),
                ),
                const Divider(color: Colors.white24),
                ListTile(
                  title: const Text("Bio", style: TextStyle(color: Colors.white70)),
                  subtitle: Text(description, style: const TextStyle(color: Colors.white)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.white),
                    onPressed: _changeBio,
                  ),
                ),
                const Divider(color: Colors.white24),
                const SizedBox(height: 24),

                // 🔽 Regulamin (PDF)
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PdfTermsView()),
                    );
                  },
                  leading: const Icon(Icons.description, color: Colors.white),
                  title: const Text("Regulamin", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: const Color(0xFF1C2A4D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),

                const SizedBox(height: 12),

                // 🔽 Polityka Prywatności (PDF)
                ListTile(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PdfTermsView()),
                    );
                  },
                  leading: const Icon(Icons.privacy_tip, color: Colors.white),
                  title: const Text("Polityka Prywatności", style: TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: const Color(0xFF1C2A4D),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),

                const SizedBox(height: 32),

                // 🔽 Wyloguj
                ElevatedButton.icon(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    if (context.mounted) {
                      context.goNamed(AppRoutes.loginView);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.logout),
                  label: const Text("Wyloguj się"),
                ),
              ],
            ),
    );
  }
}
