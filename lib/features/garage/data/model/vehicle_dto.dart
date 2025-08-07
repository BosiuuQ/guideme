import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vehicle_dto.g.dart';

@JsonSerializable()
class VehicleDTO {
  final int id;
  final List<String> imageUrls;
  final String brand;
  final String model;

  const VehicleDTO(this.id, this.imageUrls, this.brand, this.model);

  factory VehicleDTO.fromJson(Map<String, dynamic> json) =>
      _$VehicleDTOFromJson(json);

  Map<String, dynamic> toJson() => _$VehicleDTOToJson(this);

  factory VehicleDTO.fromEntity(Vehicle vehicle) => VehicleDTO(
        vehicle.id,
        vehicle.imageUrls,
        vehicle.brand,
        vehicle.model,
      );

  Vehicle toEntity() => Vehicle(
        id: id,
        imageUrls: imageUrls,
        brand: brand,
        model: model,
      );
}
