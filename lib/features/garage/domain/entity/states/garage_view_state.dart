import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';

part 'garage_view_state.freezed.dart';

@freezed
class GarageViewState with _$GarageViewState {
  const GarageViewState._();
  const factory GarageViewState({
    @Default([]) List<Vehicle> vehicles,
    @Default([]) List<Vehicle> vehiclesToDelete,
  }) = _GarageViewState;
}
