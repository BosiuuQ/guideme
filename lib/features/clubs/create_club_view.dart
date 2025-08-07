import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CreateClubView extends StatefulWidget {
  const CreateClubView({super.key});

  @override
  State<CreateClubView> createState() => _CreateClubViewState();
}

class _CreateClubViewState extends State<CreateClubView> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  final nameController = TextEditingController();
  final bioController = TextEditingController();

  File? selectedLogoFile;
  String? uploadedLogoUrl;

  bool isOpen = true;
  bool isSubmitting = false;

  final ImagePicker picker = ImagePicker();

  Future<void> pickLogoImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedLogoFile = File(picked.path);
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

  Future<void> createClub() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Musisz być zalogowany')),
      );
      return;
    }

    if (selectedLogoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wybierz logo klubu')),
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      uploadedLogoUrl = await uploadLogoToSupabase(selectedLogoFile!);
      if (uploadedLogoUrl == null) throw Exception("Nie udało się przesłać logo.");

      final payload = {
        'name': nameController.text.trim(),
        'logo_url': uploadedLogoUrl,
        'bio': bioController.text.trim(),
        'is_open': isOpen,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Klub został utworzony!')),
        );
        context.pop(true); // ← zwraca TRUE do poprzedniego ekranu
      }
    } on PostgrestException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przy tworzeniu klubu: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd przy tworzeniu klubu: $e')),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Załóż klub", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField(nameController, "Nazwa klubu"),
              const SizedBox(height: 8),
              _buildLogoPicker(),
              _buildField(bioController, "Opis / bio klubu", maxLines: 3),
              const SizedBox(height: 12),
              _buildDropdown(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        if (_formKey.currentState!.validate()) {
                          createClub();
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Utwórz klub",
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          filled: true,
          fillColor: Colors.grey[900],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'To pole jest wymagane';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown() {
    return Row(
      children: [
        const Text("Typ klubu:",
            style: TextStyle(color: Colors.white, fontSize: 16)),
        const SizedBox(width: 12),
        DropdownButton<bool>(
          value: isOpen,
          dropdownColor: Colors.grey[900],
          style: const TextStyle(color: Colors.white),
          items: const [
            DropdownMenuItem(value: true, child: Text("Otwarty")),
            DropdownMenuItem(value: false, child: Text("Zamknięty")),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => isOpen = value);
            }
          },
        )
      ],
    );
  }

  Widget _buildLogoPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Logo klubu:",
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: pickLogoImage,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: selectedLogoFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(selectedLogoFile!, fit: BoxFit.cover),
                  )
                : const Center(
                    child: Text("Kliknij, aby wybrać logo",
                        style: TextStyle(color: Colors.white54)),
                  ),
          ),
        ),
      ],
    );
  }
}
