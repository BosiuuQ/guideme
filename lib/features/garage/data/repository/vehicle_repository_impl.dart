import 'package:guide_me/features/garage/data/datasource/mock/vehicle_mock.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/domain/repository/vehicle_repository.dart';

class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl();

  @override
  Future<List<Vehicle>> getVehicles() async {
    ///MOCK
    return vehicles;
  }

  @override
  Future<void> addVehicle(Vehicle vehicle) async {}
  @override
  Future<void> deleteVehicles(List<Vehicle> vehicles) async {}
}
