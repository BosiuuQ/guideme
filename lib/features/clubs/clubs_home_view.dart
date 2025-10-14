
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' hide ImageSource;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/clubs/clubs_list_view.dart';
import 'package:guide_me/features/clubs/my_club_view.dart';
import 'package:guide_me/features/clubs/create_club_view.dart';

class ClubsHomeView extends StatefulWidget {
  const ClubsHomeView({super.key});

  @override
  State<ClubsHomeView> createState() => _ClubsHomeViewState();
}

class _ClubsHomeViewState extends State<ClubsHomeView> {
  bool isLoading = true;
  bool isInClub = false;
  String _selectedTab = 'wszystkie';
  final supabase = Supabase.instance.client;

  // Inline create form state
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _selectedLogo;
  bool _isSubmitting = false;
  bool _isOpen = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() { isInClub = false; isLoading = false; });
      return;
    }
    try {
      final r = await supabase.from('clubs_members').select().eq('user_id', userId).limit(1);
      setState(() {
        isInClub = (r != null && (r is List) && r.isNotEmpty);
        isLoading = false;
      });
    } catch (_) {
      setState(() { isInClub = false; isLoading = false; });
    }
  }

  void _selectTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedLogo = File(picked.path);
      });
    }
  }

  Future<String?> uploadLogoToSupabase(File file) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;
    final fileName = 'logo_${DateTime.now().millisecondsSinceEpoch}_$userId.png';
    await supabase.storage.from('kluby').upload('logo/$fileName', file);
    final publicUrl = supabase.storage.from('kluby').getPublicUrl('logo/$fileName');
    return publicUrl;
  }

  Future<void> _createClubInline() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Musisz być zalogowany')));
        return;
      }

      String? uploadedLogoUrl;
      if (_selectedLogo != null) {
        uploadedLogoUrl = await uploadLogoToSupabase(_selectedLogo!);
        if (uploadedLogoUrl == null) throw Exception("Upload failed");
      }

      final payload = {
        'name': _nameController.text.trim(),
        'logo_url': uploadedLogoUrl ?? '',
        'bio': _bioController.text.trim(),
        'is_open': _isOpen,
        'total_km': 0,
        'events_count': 0,
        'user_id': user.id,
      };
      final insert = await supabase.from('clubs').insert(payload).select().single();
      await supabase.from('clubs_members').insert({
        'user_id': user.id,
        'club_id': insert['id'],
        'rola': 'Lider',
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('🎉 Klub został utworzony!')));
      // refresh state
      _nameController.clear();
      _bioController.clear();
      setState(() {
        _selectedLogo = null;
        _isSubmitting = false;
        _selectedTab = 'moje';
        _loadData();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd: $e')));
      setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF071E2F);
    final chipBlue = const Color(0xFF0A84FF);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: const Text('Kluby'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _filterChip('Wszystkie kluby', 'wszystkie', chipBlue),
                const SizedBox(width: 8),
                _filterChip('Moje kluby', 'moje', chipBlue),
                const SizedBox(width: 8),
                if (!isInClub) _filterChip('Załóż klub', 'zaloz', chipBlue),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: _buildTabContent()),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, Color primary) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () => _selectTab(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? primary : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: primary, width: 1.2),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70)),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 'moje') {
      return const MyClubView();
    } else if (_selectedTab == 'zaloz') {
      // Inline form (simplified copy of CreateClubView)
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wpisz nazwę klubu' : null,
                decoration: InputDecoration(labelText: 'Nazwa klubu', filled: true, fillColor: Colors.white10, labelStyle: const TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickLogo,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white10),
                  child: _selectedLogo != null ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(_selectedLogo!, fit: BoxFit.cover)) : const Center(child: Text('Kliknij, aby wybrać logo', style: TextStyle(color: Colors.white54))),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                decoration: InputDecoration(labelText: 'Opis / bio klubu', filled: true, fillColor: Colors.white10, labelStyle: const TextStyle(color: Colors.white70)),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Typ klubu', style: TextStyle(color: Colors.white70)),
                  const SizedBox(width: 12),
                  DropdownButton<bool>(
                    value: _isOpen,
                    items: const [
                      DropdownMenuItem(value: true, child: Text('Otwarty')),
                      DropdownMenuItem(value: false, child: Text('Zamknięty')),
                    ],
                    onChanged: (v) { if (v!=null) setState(()=>_isOpen=v); },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _createClubInline,
                child: _isSubmitting ? const CircularProgressIndicator() : const Text('Załóż klub'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );
    } else {
      return const ClubsListView();
    }
  }
}
