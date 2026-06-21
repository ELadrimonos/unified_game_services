// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'stat.dart';

class StatMapper extends ClassMapperBase<Stat> {
  StatMapper._();

  static StatMapper? _instance;
  static StatMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = StatMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Stat';

  static String _$key(Stat v) => v.key;
  static const Field<Stat, String> _f$key = Field('key', _$key);
  static num _$value(Stat v) => v.value;
  static const Field<Stat, num> _f$value = Field('value', _$value);
  static String? _$displayName(Stat v) => v.displayName;
  static const Field<Stat, String> _f$displayName = Field(
    'displayName',
    _$displayName,
    opt: true,
  );

  @override
  final MappableFields<Stat> fields = const {
    #key: _f$key,
    #value: _f$value,
    #displayName: _f$displayName,
  };

  static Stat _instantiate(DecodingData data) {
    return Stat(
      key: data.dec(_f$key),
      value: data.dec(_f$value),
      displayName: data.dec(_f$displayName),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Stat fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Stat>(map);
  }

  static Stat fromJson(String json) {
    return ensureInitialized().decodeJson<Stat>(json);
  }
}

mixin StatMappable {
  String toJson() {
    return StatMapper.ensureInitialized().encodeJson<Stat>(this as Stat);
  }

  Map<String, dynamic> toMap() {
    return StatMapper.ensureInitialized().encodeMap<Stat>(this as Stat);
  }

  StatCopyWith<Stat, Stat, Stat> get copyWith =>
      _StatCopyWithImpl<Stat, Stat>(this as Stat, $identity, $identity);
  @override
  String toString() {
    return StatMapper.ensureInitialized().stringifyValue(this as Stat);
  }

  @override
  bool operator ==(Object other) {
    return StatMapper.ensureInitialized().equalsValue(this as Stat, other);
  }

  @override
  int get hashCode {
    return StatMapper.ensureInitialized().hashValue(this as Stat);
  }
}

extension StatValueCopy<$R, $Out> on ObjectCopyWith<$R, Stat, $Out> {
  StatCopyWith<$R, Stat, $Out> get $asStat =>
      $base.as((v, t, t2) => _StatCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class StatCopyWith<$R, $In extends Stat, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? key, num? value, String? displayName});
  StatCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _StatCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Stat, $Out>
    implements StatCopyWith<$R, Stat, $Out> {
  _StatCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Stat> $mapper = StatMapper.ensureInitialized();
  @override
  $R call({String? key, num? value, Object? displayName = $none}) => $apply(
    FieldCopyWithData({
      if (key != null) #key: key,
      if (value != null) #value: value,
      if (displayName != $none) #displayName: displayName,
    }),
  );
  @override
  Stat $make(CopyWithData data) => Stat(
    key: data.get(#key, or: $value.key),
    value: data.get(#value, or: $value.value),
    displayName: data.get(#displayName, or: $value.displayName),
  );

  @override
  StatCopyWith<$R2, Stat, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _StatCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

