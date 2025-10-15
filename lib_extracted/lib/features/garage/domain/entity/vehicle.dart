class Vehicle {
  final String id;
  final String brand;
  final String model;
  final int horsepower;
  final int capacityCm3;
  final int productionYear;
  final String color;
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

  final String fuelType;
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

  final String gearbox;
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

  final String drive;
  final String note;
  final List<String> imageUrls;
  final String status; // "otwarty" lub "zamkniety"

  Vehicle({
    required this.id,
    required this.brand,
    required this.model,
    required this.horsepower,
    required this.capacityCm3,
    required this.productionYear,
    required this.color,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    required this.fuelType,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    required this.gearbox,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    required this.drive,
    required this.note,
    required this.imageUrls,
    required this.status,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id']?.toString() ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      horsepower: (json['horsepower'] as int?) ?? 0,
      capacityCm3: (json['capacity_cm3'] as int?) ?? 0,
      productionYear: (json['production_year'] as int?) ?? 0,
      color: json['color'] as String? ?? '',
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      fuelType: json['fuel_type'] as String? ?? '',
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      gearbox: json['gearbox'] as String? ?? '',
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      drive: json['drive'] as String? ?? '',
      note: json['note'] as String? ?? '',
      imageUrls: (json['image_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      status: json['status'] as String? ?? 'otwarty',
    );
  }

  /// Umożliwia stworzenie pojazdu z mapy (np. z Supabase `.single()`)
  factory Vehicle.fromMap(Map<String, dynamic> map) => Vehicle.fromJson(map);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand': brand,
      'model': model,
      'horsepower': horsepower,
      'capacity_cm3': capacityCm3,
      'production_year': productionYear,
      'color': color,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      'fuel_type': fuelType,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      'gearbox': gearbox,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      'drive': drive,
      'note': note,
      'image_urls': imageUrls,
      'status': status,
    };
  }

  /// Umożliwia utworzenie zmodyfikowanej kopii pojazdu
  Vehicle copyWith({
    String? id,
    String? brand,
    String? model,
    int? horsepower,
    int? capacityCm3,
    int? productionYear,
    String? color,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    String? fuelType,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    String? gearbox,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

    String? drive,
    String? note,
    List<String>? imageUrls,
    String? status,
  }) {
    return Vehicle(
      id: id ?? this.id,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      horsepower: horsepower ?? this.horsepower,
      capacityCm3: capacityCm3 ?? this.capacityCm3,
      productionYear: productionYear ?? this.productionYear,
      color: color ?? this.color,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      fuelType: fuelType ?? this.fuelType,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      gearbox: gearbox ?? this.gearbox,
// TODO: convert this input to a DropdownButtonFormField with predefined choices
// Suggested options for this field (example):
//   - fuel: ['Petrol', 'Diesel', 'LPG', 'Electric', 'Hybrid']
//   - gearbox: ['Manual', 'Automatic', 'Semi-automatic']
//   - drive: ['FWD', 'RWD', 'AWD', '4x4']
// This helps enforce allowed values and matches DB columns: fuel_type, gearbox, drive.

      drive: drive ?? this.drive,
      note: note ?? this.note,
      imageUrls: imageUrls ?? this.imageUrls,
      status: status ?? this.status,
    );
  }

  @override
  String toString() => '$brand $model';
}