// lib/features/garage/garage_backend.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:postgrest/postgrest.dart';
import 'package:intl/intl.dart'; // <-- import intl without alias

class GarageBackend {
  // Supabase client
  static final _client = Supabase.instance.client;

  static const String discordWebhookUrl =
      'https://discord.com/api/webhooks/1368607523279470622/s55VTId7QUti22eO35HfG9ZBZHmyJ08ozmSTwrjjQELucjwGqSTENS9Gb5dixXnqHsLG';

  static String _getCurrentUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Użytkownik nie jest zalogowany.");
    return user.id;
  }

  // ================= HELPERS =================================================

  /// Normalize incoming date string to 'yyyy-MM-dd' for Postgres.
  /// Accepts 'dd.MM.yyyy' (UI) and many ISO variants; returns a 'yyyy-MM-dd' string
  /// or the original string on failure (DB will validate).
  static String _normalizeDateForDb(String? date) {
    if (date == null) return '';
    try {
      if (date.contains('.')) {
        final parsed = DateFormat('dd.MM.yyyy').parseStrict(date);
        return DateFormat('yyyy-MM-dd').format(parsed);
      }
      // Try ISO parse
      final parsedIso = DateTime.parse(date);
      return DateFormat('yyyy-MM-dd').format(parsedIso);
    } catch (e) {
      // Try to extract yyyy-mm-dd substring
      try {
        final m = RegExp(r'(\d{4}-\d{2}-\d{2})').firstMatch(date);
        if (m != null) return m.group(1)!;
      } catch (_) {}
      // Fallback: return original (DB will validate)
      return date;
    }
  }

  /// Normalize 'date' inside a payload map if present.
  static Map<String, dynamic> _normalizeEntryDate(Map<String, dynamic> row) {
    if (row.containsKey('date')) {
      row['date'] = _normalizeDateForDb(row['date']?.toString());
    }
    return row;
  }

  // ====== LIMITY GARAŻU ======================================================

  /// Pobiera limit slotów garażu z public.users.garage_slots
  static Future<int> _getGarageSlotsForUser(String userId) async {
    final row = await _client
        .from('users') // public.users
        .select('garage_slots')
        .eq('id', userId)
        .maybeSingle();

    // Fallback, gdyby kolumna/wiersz nie istniał: 2
    final slots = (row?['garage_slots'] as int?) ?? 2;
    return slots;
  }

  /// Liczba pojazdów należących do użytkownika
  static Future<int> _getUserVehicleCount(String userId) async {
    final data = await _client
        .from('garaz')
        .select('id')
        .eq('owner_id', userId);

    return (data is List) ? data.length : 0;
  }

  /// Zwraca {used, limit} dla aktualnego usera
  static Future<Map<String, int>> getGarageUsage() async {
    final uid = _getCurrentUserId();
    final used = await _getUserVehicleCount(uid);
    final limit = await _getGarageSlotsForUser(uid);
    return {'used': used, 'limit': limit};
  }

  static Future<bool> canAddVehicle() async {
    final usage = await getGarageUsage();
    return usage['used']! < usage['limit']!;
  }

  static Future<int> getRemainingGarageSlots() async {
    final usage = await getGarageUsage();
    return (usage['limit']! - usage['used']!).clamp(0, 1 << 30);
  }

  // ====== UPLOAD OBRAZKÓW ====================================================

  static Future<String> uploadVehicleImage(File imageFile, String fileName) async {
    final bytes = await imageFile.readAsBytes();
    await _client.storage.from('garaz').uploadBinary(fileName, bytes);
    final publicUrl = _client.storage.from('garaz').getPublicUrl(fileName);
    return publicUrl;
  }

  // ====== CRUD POJAZDÓW ======================================================

  static Future<void> addVehicle(Vehicle vehicle, List<File> images) async {
    final ownerId = _getCurrentUserId();

    // TUTAJ sprawdzamy limit PRZED dodaniem
    final limit = await _getGarageSlotsForUser(ownerId);
    final used = await _getUserVehicleCount(ownerId);
    if (used >= limit) {
      throw Exception(
        'Osiągnięto limit pojazdów w garażu ($used/$limit). '
            'Zwiększ limit lub usuń istniejący pojazd.',
      );
    }

    // Upload zdjęć
    List<String> imageUrls = [];
    for (int i = 0; i < images.length; i++) {
      final ext = images[i].path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final url = await uploadVehicleImage(images[i], fileName);
      imageUrls.add(url);
    }

    // Insert pojazdu
    final data = {
      'owner_id': ownerId,
      'brand': vehicle.brand,
      'model': vehicle.model,
      'horsepower': vehicle.horsepower,
      'capacity_cm3': vehicle.capacityCm3,
      'production_year': vehicle.productionYear,
      'color': vehicle.color,
      'fuel_type': vehicle.fuelType,
      'gearbox': vehicle.gearbox,
      'drive': vehicle.drive,
      'note': vehicle.note,
      'image_urls': imageUrls,
      'status': vehicle.status,
    };

    final inserted = await _client.from('garaz').insert(data).select().single();
    final vehicleId = inserted['id'] as String;
    await _createEmptyVehicleLog(vehicleId);
  }

  static Future<void> _createEmptyVehicleLog(String vehicleId) async {
    // Create a blank log entry for the vehicle if not present.
    await _client.from('vehicle_logs').insert({
      'vehicle_id': vehicleId,
      'last_check_date': null,
      'insurance_from': null,
      'insurance_to': null,
      'oil_change_date': null,
      'oil_change_km': null,
    });
  }

  static Future<void> deleteVehicleWithLog(String vehicleId) async {
    await _client.from('vehicle_service_entries').delete().eq('vehicle_id', vehicleId);
    await _client.from('vehicle_fuel_entries').delete().eq('vehicle_id', vehicleId);
    await _client.from('vehicle_logs').delete().eq('vehicle_id', vehicleId);
    await _client.from('garaz').delete().eq('id', vehicleId);
  }

  static Future<List<Vehicle>> getVehicles() async {
    final userId = _getCurrentUserId();
    final data = await _client
        .from('garaz')
        .select('*')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    final vehicles = <Vehicle>[];

    for (final item in data) {
      final vehicle = Vehicle.fromJson(item);
      vehicles.add(vehicle);

      final log = await _client
          .from('vehicle_logs')
          .select('vehicle_id')
          .eq('vehicle_id', vehicle.id)
          .maybeSingle();

      if (log == null) {
        await _createEmptyVehicleLog(vehicle.id);
      }
    }

    return vehicles;
  }

  static Future<List<Vehicle>> getVehiclesForUser(String userId) async {
    final data = await _client
        .from('garaz')
        .select('*')
        .eq('owner_id', userId)
        .order('created_at', ascending: false);

    return (data as List).map((e) => Vehicle.fromJson(e)).toList();
  }

  static Future<Vehicle> getVehicleDetails(String vehicleId) async {
    final data = await _client
        .from('garaz')
        .select('*')
        .eq('id', vehicleId)
        .maybeSingle();

    if (data == null) throw Exception("Pojazd nie został znaleziony.");
    return Vehicle.fromJson(data);
  }

  static Future<void> updateVehicleStatus(String vehicleId, String newStatus) async {
    await _client.from('garaz').update({'status': newStatus}).eq('id', vehicleId).select();
  }

  static Future<void> updateAllVehicleStatuses(String newStatus) async {
    final userId = _getCurrentUserId();
    await _client.from('garaz').update({'status': newStatus}).eq('owner_id', userId);
  }

  static Future<String?> getGarageStatusForUser(String userId) async {
    final res = await _client
        .from('garaz')
        .select('status')
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return res?['status'] as String?;
  }

  static Future<String> getGarageStatus() async {
    final userId = _getCurrentUserId();
    final data = await _client
        .from('garaz')
        .select('status')
        .eq('owner_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return data?['status'] ?? 'otwarty';
  }

  // ====== ZGŁOSZENIA / DISCORD ===============================================

  static Future<void> reportVehicleToDiscord({
    required String vehicleId,
    required String reason,
    required String imageUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;

    await _client.from('zgloszenia_pojazdy').insert({
      'vehicle_id': vehicleId,
      'reporter_id': userId,
      'reason': reason,
      'image_url': imageUrl,
      'created_at': DateTime.now().toIso8601String(),
    });

    final embed = {
      "title": "🚨 Zgłoszenie pojazdu",
      "description": "Pojazd ID: `$vehicleId`\nPowód: **$reason**",
      "color": 15158332,
      "image": {"url": imageUrl},
      "footer": {"text": "GuideMe – Zgłoszenie od użytkownika $userId"},
    };

    await http.post(
      Uri.parse(discordWebhookUrl),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"embeds": [embed]}),
    );
  }

  // ====== LOGI POJAZDU, SERWIS, PALIWO ======================================

  static Future<Map<String, dynamic>?> fetchVehicleLog(String vehicleId) async {
    final data = await _client
        .from('vehicle_logs')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    return data;
  }

  static Future<List<Map<String, dynamic>>> fetchServiceEntries(String vehicleId) async {
    final data = await _client
        .from('vehicle_service_entries')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchFuelEntries(String vehicleId) async {
    final data = await _client
        .from('vehicle_fuel_entries')
        .select('*')
        .eq('vehicle_id', vehicleId)
        .order('date', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<Map<String, dynamic>> getMonthlyFuelStats(String vehicleId, int year, int month) async {
    final firstDay = DateTime(year, month, 1).toIso8601String();
    final lastDay = DateTime(year, month + 1, 0).toIso8601String();

    final data = await _client
        .from('vehicle_fuel_entries')
        .select('liters, pln')
        .eq('vehicle_id', vehicleId)
        .gte('date', firstDay)
        .lte('date', lastDay);

    double totalPln = 0;
    double totalLiters = 0;

    for (final entry in data) {
      totalPln += (entry['pln'] as num).toDouble();
      totalLiters += (entry['liters'] as num).toDouble();
    }

    return {
      'total_pln': totalPln,
      'total_liters': totalLiters,
      'avg_price_per_liter': totalLiters > 0 ? totalPln / totalLiters : 0,
      'count': data.length,
    };
  }

  static Future<void> updateVehicleLog({
    required String vehicleId,
    String? lastCheckDate,
    String? insuranceFrom,
    String? insuranceTo,
    String? oilChangeDate,
    int? oilChangeKm,
  }) async {
    final existing = await _client
        .from('vehicle_logs')
        .select()
        .eq('vehicle_id', vehicleId)
        .maybeSingle();

    // Normalize all date fields before insert/update
    final updates = <String, dynamic>{
      'last_check_date': lastCheckDate == null ? null : _normalizeDateForDb(lastCheckDate),
      'insurance_from': insuranceFrom == null ? null : _normalizeDateForDb(insuranceFrom),
      'insurance_to': insuranceTo == null ? null : _normalizeDateForDb(insuranceTo),
      'oil_change_date': oilChangeDate == null ? null : _normalizeDateForDb(oilChangeDate),
      'oil_change_km': oilChangeKm,
    };

    if (existing == null) {
      await _client.from('vehicle_logs').insert({
        'vehicle_id': vehicleId,
        ...updates,
      });
      return;
    }

    await _client.from('vehicle_logs').update(updates).eq('vehicle_id', vehicleId);
  }

  static Future<void> updateVehicle(Vehicle vehicle) async {
    await _client.from('garaz').update({
      'brand': vehicle.brand,
      'model': vehicle.model,
      'horsepower': vehicle.horsepower,
      'capacity_cm3': vehicle.capacityCm3,
      'production_year': vehicle.productionYear,
      'color': vehicle.color,
      'fuel_type': vehicle.fuelType,
      'gearbox': vehicle.gearbox,
      'drive': vehicle.drive,
      'note': vehicle.note,
      'status': vehicle.status,
    }).eq('id', vehicle.id);
  }

  // ADD SERVICE ENTRY WITH NORMALIZED DATE
  static Future<void> addServiceEntry({
    required String vehicleId,
    required String title,
    required String date,
    required String cost,
  }) async {
    final Map<String, dynamic> payload = _normalizeEntryDate({
      'vehicle_id': vehicleId,
      'title': title,
      'date': date,
      'cost': cost,
    });

    await _client.from('vehicle_service_entries').insert(payload);
  }

  // ADD FUEL ENTRY WITH NORMALIZED DATE
  static Future<void> addFuelEntry({
    required String vehicleId,
    required String? date,
    required double? liters,
    required double? pln,
  }) async {
    if (date == null || liters == null || pln == null) return;

    final Map<String, dynamic> payload = _normalizeEntryDate({
      'vehicle_id': vehicleId,
      'date': date,
      'liters': liters,
      'pln': pln,
    });

    await _client.from('vehicle_fuel_entries').insert(payload);
  }
}
