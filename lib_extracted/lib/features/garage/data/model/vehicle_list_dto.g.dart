// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_list_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VehicleListDTO _$VehicleListDTOFromJson(Map<String, dynamic> json) =>
    VehicleListDTO(
      (json['vehicles'] as List<dynamic>)
          .map((e) => VehicleDTO.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VehicleListDTOToJson(VehicleListDTO instance) =>
    <String, dynamic>{
      'vehicles': instance.vehicles,
    };
