// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle_dto.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VehicleDTO _$VehicleDTOFromJson(Map<String, dynamic> json) => VehicleDTO(
      (json['id'] as num).toInt(),
      (json['imageUrls'] as List<dynamic>).map((e) => e as String).toList(),
      json['brand'] as String,
      json['model'] as String,
    );

Map<String, dynamic> _$VehicleDTOToJson(VehicleDTO instance) =>
    <String, dynamic>{
      'id': instance.id,
      'imageUrls': instance.imageUrls,
      'brand': instance.brand,
      'model': instance.model,
    };
