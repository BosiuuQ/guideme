// 📁 garage_backend.dart – z obsługą zakładki paliwo i statystyk miesięcznych

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:postgrest/postgrest.dart';

class GarageBackend {
  static final _client = Supabase.instance.client;

  static const String discordWebhookUrl =
      'https://discord.com/api/webhooks/1368607523279470622/s55VTId7QUti22eO35HfG9ZBZHmyJ08ozmSTwrjjQELucjwGqSTENS9Gb5dixXnqHsLG';

  static String _getCurrentUserId() {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception("Użytkownik nie jest zalogowany.");
    return user.id;
  }

  static Future<String> uploadVehicleImage(File imageFile, String fileName) async {
    final bytes = await imageFile.readAsBytes();
    await _client.storage.from('garaz').uploadBinary(fileName, bytes);
    final publicUrl = _client.storage.from('garaz').getPublicUrl(fileName);
    return publicUrl;
  }

  static Future<void> addVehicle(Vehicle vehicle, List<File> images) async {
    final ownerId = _getCurrentUserId();
    List<String> imageUrls = [];

    for (int i = 0; i < images.length; i++) {
      final ext = images[i].path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final url = await uploadVehicleImage(images[i], fileName);
      imageUrls.add(url);
    }

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
    final vehicleId = inserted['id'];
    await _createEmptyVehicleLog(vehicleId);
  }

  static Future<void> _createEmptyVehicleLog(String vehicleId) async {
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

    final updates = {
      'last_check_date': lastCheckDate,
      'insurance_from': insuranceFrom,
      'insurance_to': insuranceTo,
      'oil_change_date': oilChangeDate,
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

  static Future<void> addServiceEntry({
    required String vehicleId,
    required String title,
    required String date,
    required String cost,
  }) async {
    await _client.from('vehicle_service_entries').insert({
      'vehicle_id': vehicleId,
      'title': title,
      'date': date,
      'cost': cost,
    });
  }

  static Future<void> addFuelEntry({
    required String vehicleId,
    required String? date,
    required double? liters,
    required double? pln,
  }) async {
    if (date == null || liters == null || pln == null) return;

    await _client.from('vehicle_fuel_entries').insert({
      'vehicle_id': vehicleId,
      'date': date,
      'liters': liters,
      'pln': pln,
    });
  }
}
