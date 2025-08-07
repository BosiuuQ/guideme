// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'garage_view_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$GarageViewState {
  List<Vehicle> get vehicles => throw _privateConstructorUsedError;
  List<Vehicle> get vehiclesToDelete => throw _privateConstructorUsedError;

  /// Create a copy of GarageViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $GarageViewStateCopyWith<GarageViewState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $GarageViewStateCopyWith<$Res> {
  factory $GarageViewStateCopyWith(
          GarageViewState value, $Res Function(GarageViewState) then) =
      _$GarageViewStateCopyWithImpl<$Res, GarageViewState>;
  @useResult
  $Res call({List<Vehicle> vehicles, List<Vehicle> vehiclesToDelete});
}

/// @nodoc
class _$GarageViewStateCopyWithImpl<$Res, $Val extends GarageViewState>
    implements $GarageViewStateCopyWith<$Res> {
  _$GarageViewStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of GarageViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vehicles = null,
    Object? vehiclesToDelete = null,
  }) {
    return _then(_value.copyWith(
      vehicles: null == vehicles
          ? _value.vehicles
          : vehicles // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
      vehiclesToDelete: null == vehiclesToDelete
          ? _value.vehiclesToDelete
          : vehiclesToDelete // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$GarageViewStateImplCopyWith<$Res>
    implements $GarageViewStateCopyWith<$Res> {
  factory _$$GarageViewStateImplCopyWith(_$GarageViewStateImpl value,
          $Res Function(_$GarageViewStateImpl) then) =
      __$$GarageViewStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({List<Vehicle> vehicles, List<Vehicle> vehiclesToDelete});
}

/// @nodoc
class __$$GarageViewStateImplCopyWithImpl<$Res>
    extends _$GarageViewStateCopyWithImpl<$Res, _$GarageViewStateImpl>
    implements _$$GarageViewStateImplCopyWith<$Res> {
  __$$GarageViewStateImplCopyWithImpl(
      _$GarageViewStateImpl _value, $Res Function(_$GarageViewStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of GarageViewState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? vehicles = null,
    Object? vehiclesToDelete = null,
  }) {
    return _then(_$GarageViewStateImpl(
      vehicles: null == vehicles
          ? _value._vehicles
          : vehicles // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
      vehiclesToDelete: null == vehiclesToDelete
          ? _value._vehiclesToDelete
          : vehiclesToDelete // ignore: cast_nullable_to_non_nullable
              as List<Vehicle>,
    ));
  }
}

/// @nodoc

class _$GarageViewStateImpl extends _GarageViewState {
  const _$GarageViewStateImpl(
      {final List<Vehicle> vehicles = const [],
      final List<Vehicle> vehiclesToDelete = const []})
      : _vehicles = vehicles,
        _vehiclesToDelete = vehiclesToDelete,
        super._();

  final List<Vehicle> _vehicles;
  @override
  @JsonKey()
  List<Vehicle> get vehicles {
    if (_vehicles is EqualUnmodifiableListView) return _vehicles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_vehicles);
  }

  final List<Vehicle> _vehiclesToDelete;
  @override
  @JsonKey()
  List<Vehicle> get vehiclesToDelete {
    if (_vehiclesToDelete is EqualUnmodifiableListView)
      return _vehiclesToDelete;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_vehiclesToDelete);
  }

  @override
  String toString() {
    return 'GarageViewState(vehicles: $vehicles, vehiclesToDelete: $vehiclesToDelete)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$GarageViewStateImpl &&
            const DeepCollectionEquality().equals(other._vehicles, _vehicles) &&
            const DeepCollectionEquality()
                .equals(other._vehiclesToDelete, _vehiclesToDelete));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_vehicles),
      const DeepCollectionEquality().hash(_vehiclesToDelete));

  /// Create a copy of GarageViewState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$GarageViewStateImplCopyWith<_$GarageViewStateImpl> get copyWith =>
      __$$GarageViewStateImplCopyWithImpl<_$GarageViewStateImpl>(
          this, _$identity);
}

abstract class _GarageViewState extends GarageViewState {
  const factory _GarageViewState(
      {final List<Vehicle> vehicles,
      final List<Vehicle> vehiclesToDelete}) = _$GarageViewStateImpl;
  const _GarageViewState._() : super._();

  @override
  List<Vehicle> get vehicles;
  @override
  List<Vehicle> get vehiclesToDelete;

  /// Create a copy of GarageViewState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$GarageViewStateImplCopyWith<_$GarageViewStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
