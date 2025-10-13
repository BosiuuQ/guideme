import 'package:guide_me/features/garage/domain/entity/states/garage_view_state.dart';
import 'package:guide_me/features/garage/domain/entity/vehicle.dart';
import 'package:guide_me/features/garage/presentation/providers/vehicle_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_list_notifier.g.dart';

@riverpod
class VehicleListNotifier extends _$VehicleListNotifier {
  @override
  FutureOr<GarageViewState> build() async {
    final getVehicles = ref.read(getVehiclesProvider);
    final vehicles = await getVehicles();
    await Future.delayed(Duration(seconds: 1));
    return GarageViewState(vehicles: vehicles);
  }

  Future<void> deleteVehicles() async {
    final currentState = state.value;
    if (currentState != null) {
      List<Vehicle> currentVehicles = List<Vehicle>.from(currentState.vehicles);
      currentVehicles.removeWhere(
          (vehicle) => currentState.vehiclesToDelete.contains(vehicle));
      state = AsyncData(currentState.copyWith(
        vehicles: currentVehicles,
        vehiclesToDelete: [],
      ));
    }
  }

  void toggleVehicleToDeleteList(Vehicle vehicle) {
    final currentState = state.value;
    if (currentState != null) {
      if (currentState.vehiclesToDelete.contains(vehicle)) {
        _removeVehicleToDelete(vehicle);
      } else {
        _addVehicleToDeleteList(vehicle);
      }
    }
  }

  void _addVehicleToDeleteList(Vehicle vehicle) {
    final currentState = state.value;
    if (currentState != null) {
      if (!currentState.vehiclesToDelete.contains(vehicle)) {
        final updatedList = List<Vehicle>.from(currentState.vehiclesToDelete)
          ..add(vehicle);
        state = AsyncData(currentState.copyWith(vehiclesToDelete: updatedList));
      }
    }
  }

  void _removeVehicleToDelete(Vehicle vehicle) {
    final currentState = state.value;
    if (currentState != null) {
      final updatedList = List<Vehicle>.from(currentState.vehiclesToDelete)
        ..remove(vehicle);
      state = AsyncData(currentState.copyWith(vehiclesToDelete: updatedList));
    }
  }
}
