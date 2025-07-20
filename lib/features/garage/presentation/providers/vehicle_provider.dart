import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:guide_me/features/garage/data/repository/vehicle_repository_impl.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/domain/repository/vehicle_repository.dart';
import 'package:guide_me/features/garage/domain/use_case/add_vehicle_use_case.dart';
import 'package:guide_me/features/garage/domain/use_case/get_vehicles_use_case.dart';

final vehicleRepositoryProvider =
    Provider.autoDispose<VehicleRepository>((ref) {
  return VehicleRepositoryImpl();
});

///Get [Vehicle] list Provider
final getVehiclesProvider = Provider.autoDispose<GetVehicles>((ref) {
  final repository = ref.watch(vehicleRepositoryProvider);
  return GetVehicles(repository);
});

///Add new [Vehicle] Provider
final addVehicleProvider = Provider.autoDispose<AddVehicle>((ref) {
  final repository = ref.watch(vehicleRepositoryProvider);
  return AddVehicle(repository);
});
