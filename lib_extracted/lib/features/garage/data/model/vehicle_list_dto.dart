import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guide_me/features/garage/data/model/vehicle_dto.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';

part 'vehicle_list_dto.g.dart';

@JsonSerializable()
class VehicleListDTO {
  final List<VehicleDTO> vehicles;

  const VehicleListDTO(this.vehicles);

  factory VehicleListDTO.fromJson(Map<String, dynamic> json) =>
      _$VehicleListDTOFromJson(json);

  Map<String, dynamic> toJson() => _$VehicleListDTOToJson(this);

  factory VehicleListDTO.fromEntity(List<Vehicle> vehicles) {
    final mappedVehicles =
        vehicles.map((value) => VehicleDTO.fromEntity(value)).toList();
    return VehicleListDTO(mappedVehicles);
  }

  List<Vehicle> toEntity() =>
      vehicles.map((vehicleDTO) => vehicleDTO.toEntity()).toList();
}
