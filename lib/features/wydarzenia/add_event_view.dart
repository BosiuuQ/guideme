import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:guide_me/features/wydarzenia/backend/events_backend.dart';
import 'package:guide_me/features/wydarzenia/models/event_model.dart';

class AddEventView extends StatefulWidget {
  const AddEventView({super.key});

  @override
  State<AddEventView> createState() => _AddEventViewState();
}

class _AddEventViewState extends State<AddEventView> {
  final backend = EventsBackend();
  final _formKey = GlobalKey<FormState>();

  final titleController = TextEditingController();
  final descController = TextEditingController();
  final locController = TextEditingController();
  final imageUrlController = TextEditingController();

  DateTime? start;
  DateTime? end;

  Future<DateTime?> _pickDateTime(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now(),
    );

    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate() || start == null || end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uzupełnij wszystkie pola i wybierz daty')),
      );
      return;
    }

    final userId = await backend.getCurrentUserId();
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Błąd: Nie udało się pobrać ID użytkownika')),
      );
      return;
    }

    await backend.addEvent(Event(
      id: '',
      title: titleController.text,
      description: descController.text,
      location: locController.text,
      startTime: start!,
      endTime: end!,
      type: 'community',
      imageUrl: imageUrlController.text,
      creatorId: userId,
    ));

    if (!mounted) return;
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('✨ Dodaj wydarzenie')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      '📝 Stwórz swoje wydarzenie',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),

                    _buildTextField(titleController, 'Nazwa wydarzenia', Icons.title),
                    _buildTextField(descController, 'Opis wydarzenia', Icons.description, maxLines: 3),
                    _buildTextField(locController, 'Lokalizacja', Icons.location_on),
                    _buildTextField(imageUrlController, 'Link do zdjęcia (URL)', Icons.image),

                    const SizedBox(height: 16),

                    _buildDateTimePicker(
                      label: 'Data rozpoczęcia',
                      dateTime: start,
                      icon: Icons.calendar_month,
                      onTap: () async {
                        final picked = await _pickDateTime(context);
                        if (picked != null) setState(() => start = picked);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildDateTimePicker(
                      label: 'Data zakończenia',
                      dateTime: end,
                      icon: Icons.calendar_today,
                      onTap: () async {
                        final picked = await _pickDateTime(context);
                        if (picked != null) setState(() => end = picked);
                      },
                    ),

                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Utwórz wydarzenie'),
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: (value) => value == null || value.isEmpty ? 'To pole jest wymagane' : null,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String label,
    required DateTime? dateTime,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: Colors.grey[900],
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        dateTime != null ? DateFormat('dd.MM.yyyy • HH:mm').format(dateTime) : 'Wybierz...',
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.edit_calendar),
    );
  }
}
