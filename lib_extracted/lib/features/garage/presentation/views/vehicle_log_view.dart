import 'package:flutter/material.dart';
import 'package:guide_me/features/garage/garage_backend.dart';
import 'package:intl/intl.dart';

class VehicleLogView extends StatefulWidget {
  final String vehicleId;
  const VehicleLogView({super.key, required this.vehicleId});

  @override
  State<VehicleLogView> createState() => _VehicleLogViewState();
}

class _VehicleLogViewState extends State<VehicleLogView> with TickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> logData = {
    'last_check_date': null,
    'insurance_from': null,
    'insurance_to': null,
    'oil_change_date': null,
    'oil_change_km': null,
  };

  List<Map<String, dynamic>> serviceEntries = [];
  List<Map<String, dynamic>> fuelEntries = [];
  Map<String, dynamic> fuelStats = {};
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final log = await GarageBackend.fetchVehicleLog(widget.vehicleId);
      final repairs = await GarageBackend.fetchServiceEntries(widget.vehicleId);
      final fuels = await GarageBackend.fetchFuelEntries(widget.vehicleId);
      final stats = await GarageBackend.getMonthlyFuelStats(
        widget.vehicleId,
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (mounted) {
        setState(() {
          logData = log ?? {};
          serviceEntries = repairs;
          fuelEntries = fuels;
          fuelStats = stats;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Błąd ładowania danych: $e")),
      );
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pl', 'PL'),
    );
    if (picked != null) {
      controller.text = DateFormat('dd.MM.yyyy').format(picked);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool number = false, bool isDate = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        readOnly: isDate,
        onTap: isDate ? () => _pickDate(controller) : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

 void _showEditLogDialog() async {
  final checkController = TextEditingController(text: logData['last_check_date'] ?? '');
  final insFromController = TextEditingController(text: logData['insurance_from'] ?? '');
  final insToController = TextEditingController(text: logData['insurance_to'] ?? '');
  final oilDateController = TextEditingController(text: logData['oil_change_date'] ?? '');
  final oilKmController = TextEditingController(text: logData['oil_change_km']?.toString() ?? '');

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edytuj informacje o pojeździe"),
      content: SingleChildScrollView(
        child: Column(
          children: [
            _buildTextField("Data przeglądu", checkController, isDate: true),
            _buildTextField("Ubezpieczenie od", insFromController, isDate: true),
            _buildTextField("Ubezpieczenie do", insToController, isDate: true),
            _buildTextField("Data wymiany oleju", oilDateController, isDate: true),
            _buildTextField("Przebieg przy wymianie", oilKmController, number: true),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Anuluj"),
        ),
        ElevatedButton(
          onPressed: () async {
            if (checkController.text.isEmpty ||
                insFromController.text.isEmpty ||
                insToController.text.isEmpty ||
                oilDateController.text.isEmpty ||
                oilKmController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Wszystkie pola muszą być wypełnione.")),
              );
              return;
            }

            try {
              await GarageBackend.updateVehicleLog(
                vehicleId: widget.vehicleId,
                lastCheckDate: checkController.text,
                insuranceFrom: insFromController.text,
                insuranceTo: insToController.text,
                oilChangeDate: oilDateController.text,
                oilChangeKm: int.tryParse(oilKmController.text),
              );

              await _loadData(); // <- WAŻNE!
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Zapisano dane.")),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Błąd zapisu: $e")),
              );
            }
          },
          child: const Text("Zapisz"),
        ),
      ],
    ),
  );
}

  Widget _buildGeneralInfo() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoTile("Data przeglądu", logData['last_check_date']),
        _buildInfoTile("Ubezpieczenie od", logData['insurance_from']),
        _buildInfoTile("Ubezpieczenie do", logData['insurance_to']),
        _buildInfoTile("Data wymiany oleju", logData['oil_change_date']),
        _buildInfoTile(
          "Przebieg przy wymianie",
          logData['oil_change_km'] != null ? "${logData['oil_change_km']} km" : null,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showEditLogDialog(),
          icon: const Icon(Icons.edit),
          label: const Text("Edytuj informacje"),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, dynamic value) {
    final display = value != null && value.toString().isNotEmpty
        ? value.toString()
        : "Brak danych – uzupełnij";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Text(display, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

 Widget _buildServiceList() {
  return Stack(
    children: [
      if (serviceEntries.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              "Brak wpisów serwisowych.\nUzupełnij historię napraw.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        )
      else
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: serviceEntries.length,
          itemBuilder: (context, index) {
            final entry = serviceEntries[index];
            return Card(
              color: Colors.white10,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(entry['title'], style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  "${entry['date']} • ${entry['cost']} PLN",
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            );
          },
        ),
      Positioned(
        bottom: 24,
        right: 24,
        child: FloatingActionButton(
          onPressed: _showAddServiceDialog,
          backgroundColor: Colors.blueAccent,
          child: const Icon(Icons.add),
        ),
      ),
    ],
  );
}

void _showAddServiceDialog() async {
  final titleController = TextEditingController();
  final costController = TextEditingController();
  final dateController = TextEditingController();
  DateTime? selectedDate;

  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Dodaj wpis serwisowy"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: "Tytuł naprawy"),
          ),
          TextField(
            controller: costController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: "Koszt (PLN)"),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('pl', 'PL'),
              );
              if (picked != null) {
                selectedDate = picked;
                dateController.text = DateFormat('dd.MM.yyyy').format(picked);
              }
            },
            child: AbsorbPointer(
              child: TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: "Data naprawy"),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
        ElevatedButton(
          onPressed: () async {
            if (selectedDate != null &&
                titleController.text.isNotEmpty &&
                costController.text.isNotEmpty) {
              await GarageBackend.addServiceEntry(
                vehicleId: widget.vehicleId,
                title: titleController.text,
                date: DateFormat('dd.MM.yyyy').format(selectedDate!),
                cost: costController.text,
              );
              _loadData();
              Navigator.pop(context);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Uzupełnij wszystkie pola")),
              );
            }
          },
          child: const Text("Dodaj"),
        ),
      ],
    ),
  );
}


 Widget _buildFuelTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Statystyki: ${DateFormat('MMMM yyyy', 'pl').format(_selectedMonth)}",
                  style: const TextStyle(color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.white70),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedMonth,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    locale: const Locale('pl', 'PL'),
                  );
                  if (picked != null) {
                    setState(() => _selectedMonth = picked);
                    _loadData();
                  }
                },
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("🔹 Ilość tankowań: ${fuelStats['count'] ?? 0}", style: const TextStyle(color: Colors.white70)),
              Text("🔹 Razem litrów: ${fuelStats['total_liters']?.toStringAsFixed(2) ?? '0.00'}", style: const TextStyle(color: Colors.white70)),
              Text("🔹 Łącznie wydano: ${fuelStats['total_pln']?.toStringAsFixed(2) ?? '0.00'} PLN", style: const TextStyle(color: Colors.white70)),
              Text("🔹 Średnia cena za litr: ${fuelStats['avg_price_per_liter']?.toStringAsFixed(2) ?? '0.00'} PLN", style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const Divider(color: Colors.white24),
        Expanded(
          child: fuelEntries.isEmpty
              ? const Center(child: Text("Brak wpisów tankowań", style: TextStyle(color: Colors.white60)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: fuelEntries.length,
                  itemBuilder: (context, index) {
                    final item = fuelEntries[index];
                    return Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text("${item['liters']} L", style: const TextStyle(color: Colors.white)),
                        subtitle: Text("${item['date']} • ${item['pln']} PLN", style: const TextStyle(color: Colors.white70)),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16, right: 16),
          child: Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              onPressed: () => _showAddFuelDialog(),
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }

  void _showAddFuelDialog() async {
    final litersController = TextEditingController();
    final plnController = TextEditingController();
    final dateController = TextEditingController();
    DateTime? selectedDate;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Dodaj tankowanie"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('pl', 'PL'),
                );
                if (picked != null) {
                  selectedDate = picked;
                  dateController.text = DateFormat('dd.MM.yyyy').format(picked);
                }
              },
              child: AbsorbPointer(
                child: TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: "Data tankowania"),
                ),
              ),
            ),
            TextField(
              controller: litersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Ilość litrów"),
            ),
            TextField(
              controller: plnController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Koszt (PLN)"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Anuluj")),
          ElevatedButton(
            onPressed: () async {
              if (selectedDate == null ||
                  litersController.text.isEmpty ||
                  plnController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wszystkie pola muszą być wypełnione.")),
                );
                return;
              }

              await GarageBackend.addFuelEntry(
                vehicleId: widget.vehicleId,
                date: DateFormat('dd.MM.yyyy').format(selectedDate!),
                liters: double.tryParse(litersController.text),
                pln: double.tryParse(plnController.text),
              );
              _loadData();
              Navigator.pop(context);
            },
            child: const Text("Dodaj"),
          ),
        ],
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFF101935),
    appBar: AppBar(
      automaticallyImplyLeading: false, // ← USUWA STRZAŁKĘ
      backgroundColor: const Color(0xFF101935),
      title: const Text("Dziennik pojazdu"),
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.blueAccent,
        tabs: const [
          Tab(text: "Informacje"),
          Tab(text: "Serwis"),
          Tab(text: "Paliwo"),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _buildGeneralInfo(),
        _buildServiceList(),
        _buildFuelTab(),
      ],
       ),
    );
  }
}