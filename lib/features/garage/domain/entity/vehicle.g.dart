// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vehicle.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$VehicleImpl _$$VehicleImplFromJson(Map<String, dynamic> json) =>
    _$VehicleImpl(
      id: json['id'] as String,
      ownerId: json['ownerId'] as String,
      imageUrls:
          (json['imageUrls'] as List<dynamic>).map((e) => e as String).toList(),
      brand: json['brand'] as String,
      model: json['model'] as String,
      horsepower: (json['horsepower'] as num).toInt(),
      capacityCm3: (json['capacityCm3'] as num).toInt(),
      productionYear: (json['productionYear'] as num).toInt(),
      color: json['color'] as String,
      fuelType: json['fuelType'] as String,
      gearbox: json['gearbox'] as String,
      drive: json['drive'] as String,
      note: json['note'] as String,
      status: json['status'] as String,
    );

Map<String, dynamic> _$$VehicleImplToJson(_$VehicleImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ownerId': instance.ownerId,
      'imageUrls': instance.imageUrls,
      'brand': instance.brand,
      'model': instance.model,
      'horsepower': instance.horsepower,
      'capacityCm3': instance.capacityCm3,
      'productionYear': instance.productionYear,
      'color': instance.color,
      'fuelType': instance.fuelType,
      'gearbox': instance.gearbox,
      'drive': instance.drive,
      'note': instance.note,
      'status': instance.status,
    };
