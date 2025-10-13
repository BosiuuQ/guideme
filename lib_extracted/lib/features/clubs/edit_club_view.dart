import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class EditClubView extends StatefulWidget {
  final Map<String, dynamic> club;

  const EditClubView({super.key, required this.club});

  @override
  State<EditClubView> createState() => _EditClubViewState();
}

class _EditClubViewState extends State<EditClubView> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bioController;
  bool isLoading = false;
  bool isOpen = true;
  String? logoUrl;
  File? selectedImage;

  bool isManager = false;
  List<Map<String, dynamic>> themes = [];
  int? selectedThemeId;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.club['bio'] ?? '');
    isOpen = widget.club['is_open'] ?? true;
    logoUrl = widget.club['logo_url'];
    selectedThemeId = widget.club['motyw_id'];
    _loadPermissionsAndThemes();
  }

  Future<void> _loadPermissionsAndThemes() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    final member = await supabase
        .from('clubs_members')
        .select('rola')
        .eq('club_id', widget.club['id'])
        .eq('user_id', userId)
        .maybeSingle();

    if (member != null &&
        (member['rola'] == 'Lider' || member['rola'] == 'Zastepca')) {
      isManager = true;

      final response = await supabase
          .from('motywy_clubs')
          .select('id, name, type');

      setState(() {
        themes = List<Map<String, dynamic>>.from(response);
      });
    }
  }

  Future<void> _pickLogoImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<String?> _uploadLogo(File file) async {
    final fileName =
        'club_${widget.club['id']}_${DateTime.now().millisecondsSinceEpoch}${path.extension(file.path)}';
    final bytes = await file.readAsBytes();
    final contentType = lookupMimeType(file.path);
    final filePath = 'logo/$fileName';

    await supabase.storage.from('kluby').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(contentType: contentType),
    );

    final urlResponse = supabase.storage.from('kluby').getPublicUrl(filePath);
    return urlResponse;
  }

  Future<void> _updateClub() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    String? uploadedLogoUrl = logoUrl;
    if (selectedImage != null) {
      uploadedLogoUrl = await _uploadLogo(selectedImage!);
    }

    final updateData = {
      'bio': _bioController.text.trim(),
      'is_open': isOpen,
      'logo_url': uploadedLogoUrl,
    };

    if (isManager && selectedThemeId != null) {
      updateData['motyw_id'] = selectedThemeId;
    }

    await supabase
        .from('clubs')
        .update(updateData)
        .eq('id', widget.club['id']);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Klub zaktualizowany')),
      );
      Navigator.pop(context);
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121829),
      appBar: AppBar(
        title: const Text("Edytuj klub"),
        backgroundColor: const Color(0xFF1F2A44),
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: _inputDecoration("Opis klubu"),
                      style: const TextStyle(color: Colors.white),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Wpisz opis' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<bool>(
                      value: isOpen,
                      decoration: _inputDecoration("Typ klubu"),
                      dropdownColor: const Color(0xFF1F2A44),
                      style: const TextStyle(color: Colors.white),
                      items: const [
                        DropdownMenuItem(value: true, child: Text("Otwarty")),
                        DropdownMenuItem(value: false, child: Text("Zamknięty")),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => isOpen = val);
                      },
                    ),
                    const SizedBox(height: 16),
                    if (isManager && themes.isNotEmpty) ...[
                      const Text("🎨 Motyw klubu",
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: selectedThemeId,
                        decoration: _inputDecoration("Wybierz motyw"),
                        dropdownColor: const Color(0xFF1F2A44),
                        style: const TextStyle(color: Colors.white),
                        items: themes.map((motyw) {
                          return DropdownMenuItem<int>(
                            value: motyw['id'] as int,
                            child: Text(motyw['name']),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => selectedThemeId = val);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                    ],
                    const Text("🖼️ Logo klubu",
                        style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickLogoImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: selectedImage != null
                            ? Image.file(selectedImage!,
                                height: 160, fit: BoxFit.cover)
                            : (logoUrl != null && logoUrl!.isNotEmpty
                                ? Image.network(logoUrl!,
                                    height: 160, fit: BoxFit.cover)
                                : Container(
                                    height: 160,
                                    color: Colors.black12,
                                    child: const Center(
                                        child: Icon(Icons.add_a_photo,
                                            color: Colors.white54, size: 32)),
                                  )),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _updateClub,
                      icon: const Icon(Icons.save),
                      label: const Text("Zapisz zmiany"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      filled: true,
      fillColor: const Color(0xFF1F2A44),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
