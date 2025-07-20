import 'package:guide_me/features/garage/domain/entity/vehicle.dart';

abstract class VehicleRepository {
  Future<List<Vehicle>> getVehicles();
  Future<void> addVehicle(Vehicle vehicle);
  Future<void> deleteVehicles(List<Vehicle> vehicles);
}
