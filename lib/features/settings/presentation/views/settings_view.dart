import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/features/settings/settings_backend.dart';
import 'package:guide_me/features/settings/presentation/views/pdftermsview.dart';

class SettingsView extends ConsumerStatefulWidget {
  const SettingsView({super.key});

  @override
  ConsumerState<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends ConsumerState<SettingsView> {
  // -------- DATA --------
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _appInfo = {};
  List<Map<String, dynamic>> _blocked = [];

  bool _loading = true;

  // -------- STYLE --------
  static const _bg = Color(0xFF0B1224);
  static const _card = Color(0x221C2A4D); // delikatny glass
  static const _cardBorder = Color(0x33A7B5FF);
  static const _primary = Color(0xFFA7B5FF);
  static const _tile = Color(0xFF1A2647);

  // Wersja aplikacji ustawiona ręcznie (żądanie)
  static const String _fixedAppVersion = '0.2.0';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final profile = await SettingsBackend.getUserProfile();
      final stats = await SettingsBackend.getUserStats();
      final info = await SettingsBackend.getAppInfo();    // nie używamy do wersji – wersja na sztywno
      final blocked = await SettingsBackend.getBlockedUsers();

      if (!mounted) return;
      setState(() {
        _profile = profile ?? {};
        _stats = stats ?? {};
        _appInfo = info ?? {};
        _blocked = blocked ?? [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Nie udało się załadować ustawień: $e');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // -------- AVATAR --------
  Future<void> _changeAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final file = File(picked.path);
      await SettingsBackend.updateAvatar(file);
      await _loadAll();
      _snack('Zmieniono avatar');
    } catch (e) {
      _snack('Błąd podczas zmiany avatara: $e');
    }
  }

  // -------- INLINE EDITORS --------
  Future<void> _editTextField({
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
    String? hint,
    TextInputType? keyboardType,
    bool obscure = false,
  }) async {
    final controller = TextEditingController(text: initial);
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _tile,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: const Color(0xFF0F1834),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Zapisz'),
          ),
        ],
      ),
    );
    if (res == null) return;
    if (res.isEmpty) {
      _snack('Pole nie może być puste');
      return;
    }
    try {
      await onSave(res);
      await _loadAll();
      _snack('Zapisano zmiany');
    } catch (e) {
      _snack('Błąd zapisu: $e');
    }
  }

  Future<void> _changeNickname() async {
    await _editTextField(
      title: 'Zmień nick',
      initial: _profile['nickname'] ?? '',
      onSave: (v) => SettingsBackend.updateNickname(v),
      hint: 'Wpisz nowy nick',
    );
  }

  Future<void> _changeBio() async {
    await _editTextField(
      title: 'Zmień bio',
      initial: _profile['description'] ?? '',
      maxLines: 4,
      onSave: (v) => SettingsBackend.updateBio(v),
      hint: 'Krótki opis o Tobie…',
    );
  }

  Future<void> _changeEmail() async {
    await _editTextField(
      title: 'Zmień e-mail',
      initial: _profile['email'] ?? '',
      keyboardType: TextInputType.emailAddress,
      onSave: (v) => SettingsBackend.updateEmail(v),
      hint: 'nowy@email.com',
    );
  }

  Future<void> _changePassword() async {
    await _editTextField(
      title: 'Zmień hasło',
      initial: '',
      obscure: true,
      onSave: (v) => SettingsBackend.updatePassword(v),
      hint: 'Min. 8 znaków',
    );
  }

  // -------- BLOCKED USERS --------
  Future<void> _unblock(String userId) async {
    try {
      await SettingsBackend.unblockUser(userId);
      await _loadAll();
      _snack('Użytkownik odblokowany');
    } catch (e) {
      _snack('Nie udało się odblokować: $e');
    }
  }

  // -------- ACCOUNT ACTIONS --------
  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    context.goNamed(AppRoutes.loginView);
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _tile,
        title: const Text('Usuń konto', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Tej operacji nie można cofnąć. Czy na pewno chcesz usunąć konto?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Usuń'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await SettingsBackend.deleteAccount();
      await _signOut();
    } catch (e) {
      _snack('Nie udało się usunąć konta: $e');
    }
  }

  // -------- HELPERS UI --------
  Widget _glassCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder, width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 16, spreadRadius: -6, offset: Offset(0, 6)),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _sectionTitle(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: _primary, size: 20),
          if (icon != null) const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statsGrid() {
    final level = _stats['account_lvl'] ?? 1;
    final points = _stats['guidepoints'] ?? 0;
    final kmPretty = _stats['km_total_pretty'] ?? '0,00 km';
    final posts = _stats['posts'] ?? 0;
    final viewpoints = _stats['viewpoints'] ?? 0;
    final createdPretty = _stats['created_at_pretty'] ?? '—';

    Widget tile(String label, String value, IconData icon) {
      return _glassCard(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0x1FA7B5FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _cardBorder),
              ),
              child: Icon(icon, color: _primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // więcej wysokości kafelków (unikamy overflow)
    final gridDelegate = const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    );

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: gridDelegate,
      children: [
        tile('Poziom', '$level', Icons.auto_graph),
        tile('GuidePoints', '$points', Icons.stars_rounded),
        tile('Przejechane km', kmPretty, Icons.route),
        tile('Posty', '$posts', Icons.photo_library_outlined),
        tile('Punkty widokowe', '$viewpoints', Icons.landscape),
        tile('Założono', createdPretty, Icons.event_available),
      ],
    );
  }

  Widget _editableRow({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onEdit,
  }) {
    return _glassCard(
      child: Row(
        children: [
          Icon(icon, color: _primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '—' : value, style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit, color: Colors.white),
            tooltip: 'Edytuj',
          ),
        ],
      ),
    );
  }

  Widget _navTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: _tile,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _profile['avatar'] as String? ?? "";
    final nickname = _profile['nickname'] as String? ?? "Brak nicku";
    final description = _profile['description'] as String? ?? "Brak opisu";
    final email = _profile['email'] as String? ?? "—";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ustawienia"),
        backgroundColor: _bg,
        elevation: 0,
        automaticallyImplyLeading: true, // strzałka cofania
      ),
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // HEADER: Avatar + Nick
                  _glassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _changeAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 56,
                                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                backgroundColor: const Color(0x33223166),
                                child: avatarUrl.isEmpty
                                    ? const Icon(Icons.person, size: 56, color: Colors.white54)
                                    : null,
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF243469),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _cardBorder),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(nickname, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _changeNickname,
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Zmień nick'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(color: _primary),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _changeBio,
                              icon: const Icon(Icons.notes, size: 18),
                              label: const Text('Zmień bio'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(color: _primary),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _changeAvatar,
                              icon: const Icon(Icons.camera_alt, size: 18),
                              label: const Text('Zmień avatar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _primary,
                                side: const BorderSide(color: _primary),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // STATS
                  _sectionTitle('Informacje o użytkowniku', icon: Icons.insights),
                  _statsGrid(),
                  const SizedBox(height: 20),

                  // ACCOUNT FIELDS
                  _sectionTitle('Konto i bezpieczeństwo', icon: Icons.lock),
                  _editableRow(
                    label: 'Adres e-mail',
                    value: email,
                    icon: Icons.alternate_email,
                    onEdit: _changeEmail,
                  ),
                  const SizedBox(height: 12),
                  _editableRow(
                    label: 'Hasło',
                    value: '••••••••',
                    icon: Icons.password_rounded,
                    onEdit: _changePassword,
                  ),
                  const SizedBox(height: 20),

                  // INFORMACJE
                  _sectionTitle('Informacje', icon: Icons.info_outline),
                  _glassCard(
                    child: Column(
                      children: [
                        _infoRow('Wersja aplikacji', _fixedAppVersion),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final changelog = await SettingsBackend.getChangelog();
                                  if (!mounted) return;
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      backgroundColor: _tile,
                                      title: const Text('Co nowego', style: TextStyle(color: Colors.white)),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          (changelog?.toString().trim().isNotEmpty ?? false)
                                              ? changelog.toString()
                                              : 'Brak informacji.',
                                          style: const TextStyle(color: Colors.white70),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Zamknij')),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.new_releases),
                                label: const Text('Co nowego'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2B3F7A),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    title: 'Regulamin',
                    icon: Icons.description,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfTermsView()));
                    },
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    title: 'Polityka prywatności',
                    icon: Icons.privacy_tip,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfTermsView()));
                    },
                  ),
                  const SizedBox(height: 12),
                  _navTile(
                    title: 'Kontakt',
                    icon: Icons.support_agent,
                    onTap: () async {
                      final contact = await SettingsBackend.getContactInfo();
                      if (!mounted) return;
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          backgroundColor: _tile,
                          title: const Text('Kontakt', style: TextStyle(color: Colors.white)),
                          content: Text(
                            'E-mail: ${contact?['email'] ?? 'support@guideme.app'}\n'
                            'Discord: ${contact?['discord'] ?? '@guideme.official'}\n'
                            'WWW: ${contact?['www'] ?? 'guideme.app'}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zamknij'))],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // TEAM - expandable
                  ExpansionTile(
                    backgroundColor: _card,
                    collapsedBackgroundColor: _card,
                    collapsedIconColor: Colors.white54,
                    iconColor: Colors.white,
                    title: const Text("Zespół GuideMe", style: TextStyle(color: Colors.white)),
                    leading: const Icon(Icons.verified_user, color: Colors.white),
                    children: [
                      _teamRow(name: 'Marcin', role: 'CEO / Co-Founder'),
                      const SizedBox(height: 10),
                      _teamRow(name: 'Jakub', role: 'CEO / Co-Founder'),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // BLOCKED LIST - expandable
                  ExpansionTile(
                    backgroundColor: _card,
                    collapsedBackgroundColor: _card,
                    collapsedIconColor: Colors.white54,
                    iconColor: Colors.white,
                    title: const Text("Lista zablokowanych", style: TextStyle(color: Colors.white)),
                    leading: const Icon(Icons.block, color: Colors.white),
                    children: _blocked.isEmpty
                        ? [const Padding(padding: EdgeInsets.all(12), child: Text('Brak zablokowanych', style: TextStyle(color: Colors.white70)))]
                        : _blocked.map((u) => _blockedTile(u)).toList(),
                  ),

                  const SizedBox(height: 28),

                  // DANGER ZONE
                  _sectionTitle('Strefa konta', icon: Icons.warning_amber_rounded),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deleteAccount,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: const Icon(Icons.delete_forever),
                          label: const Text('Usuń konto'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _signOut,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.logout),
                          label: const Text('Wyloguj się'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        Text(value, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  // 🔧 NAPRAWA: Expanded, żeby uniknąć RenderFlex overflow w wierszu
  Widget _teamRow({required String name, required String role}) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 18,
          backgroundColor: Color(0x33223166),
          child: Icon(Icons.person, color: Colors.white70),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              Text(role, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _blockedTile(Map<String, dynamic> u) {
    final id = u['id']?.toString() ?? '';
    final nick = u['nickname']?.toString() ?? '—';
    final reason = u['reason']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: const CircleAvatar(
          backgroundColor: Color(0x33223166),
          child: Icon(Icons.block, color: Colors.white70),
        ),
        title: Text(nick, style: const TextStyle(color: Colors.white)),
        subtitle: reason.isNotEmpty ? Text(reason, style: const TextStyle(color: Colors.white54)) : null,
        trailing: TextButton(
          onPressed: () => _unblock(id),
          child: const Text('Odblokuj'),
        ),
      ),
    );
  }
}
