import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:guide_me/features/posts/instagram_backend.dart';
import 'package:guide_me/core/config/routing/app_routes.dart';
import 'package:guide_me/core/utils/image_compression_helper.dart';

class PostAddView extends StatefulWidget {
  const PostAddView({Key? key}) : super(key: key);

  @override
  State<PostAddView> createState() => _PostAddViewState();
}

class _PostAddViewState extends State<PostAddView> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final supabase = Supabase.instance.client;

  File? _selectedImage;
  bool _isSubmitting = false;
  bool _acceptedRules = false;

  // ---- PICK IMAGE ----
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
      maxWidth: 2048,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  // ---- SUBMIT ----
  Future<void> _submitPost() async {
    final caption = _captionController.text.trim();

    if (!_acceptedRules) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Zaznacz akceptację zasad społeczności.")),
      );
      return;
    }
    if (caption.isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wypełnij opis i wybierz zdjęcie.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // compress image before upload
      final compressedFile = await ImageCompressionHelper.compressImage(
        _selectedImage!,
        quality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      
      final fileToUpload = compressedFile ?? _selectedImage!;
      
      // upload do storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'posts/$fileName';

      final bytes = await fileToUpload.readAsBytes();
      await supabase.storage.from('instaguide').uploadBinary(path, bytes);
      final publicUrl = supabase.storage.from('instaguide').getPublicUrl(path);

      // wpis do bazy
      await InstagramBackend.addPost(caption, publicUrl);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post dodany ✅")),
      );

      // przejście do listy postów
      context.goNamed(AppRoutes.instagramPosty);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd: $e")),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---- MINI ZASADY (pełny sheet) ----
  Future<void> _showRulesSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final textStyleTitle = const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        );
        final textStyle = const TextStyle(color: Colors.white70, height: 1.4);

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Zasady InstaGuide', style: textStyleTitle),
                  const SizedBox(height: 8),
                  const Text(
                    '• Motoryzacja na pierwszym planie, ale inne tematy są OK, byle w klimacie społeczności.\n'
                    '• Szacunek i zero spamu – bez wyzwisk, nękania, floodu, clickbaitu.\n'
                    '• Twoje treści – publikuj tylko materiały, do których masz prawa/zgody.\n'
                    '• Prywatność – nie ujawniaj danych osobowych; zamazuj twarze bez zgody.\n'
                    '• Bezpieczeństwo – nie promuj nielegalnych/brawurowych zachowań; tor/track-day? Napisz to w opisie.\n'
                    '• Treści wrażliwe – bez drastyki; edukacyjne oznacz ostrzeżeniem.\n'
                    '• Reklamy i sprzedaż – oznacz #reklama / #współpraca; zakaz nielegalnych ofert.\n'
                    '• Lokalizacje – nie wrzucaj dokładnych adresów prywatnych (garaże, domy).\n'
                    '• Moderacja – treści niezgodne mogą zostać ukryte/usunięte; powtarzające się naruszenia = blokada.\n'
                    '• Zgłaszanie – użyj ••• → Zgłoś (spam/nienawiść/bezpieczeństwo/prawa aut.).',
                    style: TextStyle(color: Colors.white70, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: _acceptedRules,
                        onChanged: (v) =>
                            setState(() => _acceptedRules = v ?? false),
                        activeColor: Colors.lightBlueAccent,
                      ),
                      const Expanded(
                        child: Text(
                          'Akceptuję zasady i mam prawa do tej treści.',
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.check),
                      label: const Text('OK, rozumiem'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgStart = Color(0xFF0C0F1C);
    const bgEnd = Color(0xFF0A1F2E);

    final canPost = !_isSubmitting &&
        _acceptedRules &&
        _selectedImage != null &&
        _captionController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: bgStart,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Dodaj post', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            tooltip: 'Zasady',
            onPressed: _showRulesSheet,
            icon: const Icon(Icons.rule, color: Colors.white70),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [bgStart, bgEnd],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                children: [
                  // Karta zdjęcia
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _pickImage,
                    child: Ink(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
                      child: _selectedImage == null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.1),
                                    ),
                                  ),
                                  child: const Icon(Icons.add_a_photo_rounded,
                                      size: 42, color: Colors.white70),
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Dodaj zdjęcie',
                                  style: TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Wybierz kadr, który najlepiej pokazuje klimat.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(_selectedImage!, height: 260, fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(Icons.swap_horiz_rounded),
                                    label: const Text('Zmień zdjęcie'),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Opis
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: TextField(
                      controller: _captionController,
                      maxLines: 5,
                      minLines: 3,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'Opisz post 🙂',
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.55)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Mini-zasady inline
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.035),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mini-zasady',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14)),
                        const SizedBox(height: 8),
                        Text(
                          '• Motoryzacja na pierwszym planie (inne też OK)\n'
                          '• Szacunek, zero spamu i clickbaitu\n'
                          '• Twoje treści – miej prawa/zgody\n'
                          '• Prywatność – zamazuj twarze\n'
                          '• Bezpieczeństwo – bez promowania łamania prawa\n'
                          '• Reklamy oznacz #reklama / #współpraca',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            height: 1.35,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _showRulesSheet,
                            icon: const Icon(Icons.rule, size: 18),
                            label: const Text('Pełne zasady'),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Checkbox(
                              value: _acceptedRules,
                              onChanged: (v) =>
                                  setState(() => _acceptedRules = v ?? false),
                              activeColor: Colors.lightBlueAccent,
                            ),
                            const Expanded(
                              child: Text(
                                'Potwierdzam zgodność z zasadami i prawa do treści.',
                                style:
                                    TextStyle(color: Colors.white70, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Przyciski
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: canPost ? _submitPost : null,
                      icon: _isSubmitting
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Dodaj post'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
