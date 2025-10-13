import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/domain/repository/vehicle_repository.dart';

class GetVehicles {
  final VehicleRepository vehicleRepository;

  GetVehicles(this.vehicleRepository);

  Future<List<Vehicle>> call() async {
    return await vehicleRepository.getVehicles();
  }
}
