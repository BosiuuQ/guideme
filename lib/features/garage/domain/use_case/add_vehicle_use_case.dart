import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/domain/repository/vehicle_repository.dart';

class AddVehicle {
  final VehicleRepository vehicleRepository;

  AddVehicle(this.vehicleRepository);

  Future<void> call(Vehicle vehicle) async {
    await vehicleRepository.addVehicle(vehicle);
  }
}
