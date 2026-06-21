// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_save.dart';

class CloudSaveMetadataMapper extends ClassMapperBase<CloudSaveMetadata> {
  CloudSaveMetadataMapper._();

  static CloudSaveMetadataMapper? _instance;
  static CloudSaveMetadataMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudSaveMetadataMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CloudSaveMetadata';

  static String _$slot(CloudSaveMetadata v) => v.slot;
  static const Field<CloudSaveMetadata, String> _f$slot = Field('slot', _$slot);
  static int? _$sizeBytes(CloudSaveMetadata v) => v.sizeBytes;
  static const Field<CloudSaveMetadata, int> _f$sizeBytes = Field(
    'sizeBytes',
    _$sizeBytes,
    opt: true,
  );
  static DateTime? _$modifiedAt(CloudSaveMetadata v) => v.modifiedAt;
  static const Field<CloudSaveMetadata, DateTime> _f$modifiedAt = Field(
    'modifiedAt',
    _$modifiedAt,
    opt: true,
  );
  static String? _$deviceName(CloudSaveMetadata v) => v.deviceName;
  static const Field<CloudSaveMetadata, String> _f$deviceName = Field(
    'deviceName',
    _$deviceName,
    opt: true,
  );

  @override
  final MappableFields<CloudSaveMetadata> fields = const {
    #slot: _f$slot,
    #sizeBytes: _f$sizeBytes,
    #modifiedAt: _f$modifiedAt,
    #deviceName: _f$deviceName,
  };

  static CloudSaveMetadata _instantiate(DecodingData data) {
    return CloudSaveMetadata(
      slot: data.dec(_f$slot),
      sizeBytes: data.dec(_f$sizeBytes),
      modifiedAt: data.dec(_f$modifiedAt),
      deviceName: data.dec(_f$deviceName),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CloudSaveMetadata fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CloudSaveMetadata>(map);
  }

  static CloudSaveMetadata fromJson(String json) {
    return ensureInitialized().decodeJson<CloudSaveMetadata>(json);
  }
}

mixin CloudSaveMetadataMappable {
  String toJson() {
    return CloudSaveMetadataMapper.ensureInitialized()
        .encodeJson<CloudSaveMetadata>(this as CloudSaveMetadata);
  }

  Map<String, dynamic> toMap() {
    return CloudSaveMetadataMapper.ensureInitialized()
        .encodeMap<CloudSaveMetadata>(this as CloudSaveMetadata);
  }

  CloudSaveMetadataCopyWith<
    CloudSaveMetadata,
    CloudSaveMetadata,
    CloudSaveMetadata
  >
  get copyWith =>
      _CloudSaveMetadataCopyWithImpl<CloudSaveMetadata, CloudSaveMetadata>(
        this as CloudSaveMetadata,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CloudSaveMetadataMapper.ensureInitialized().stringifyValue(
      this as CloudSaveMetadata,
    );
  }

  @override
  bool operator ==(Object other) {
    return CloudSaveMetadataMapper.ensureInitialized().equalsValue(
      this as CloudSaveMetadata,
      other,
    );
  }

  @override
  int get hashCode {
    return CloudSaveMetadataMapper.ensureInitialized().hashValue(
      this as CloudSaveMetadata,
    );
  }
}

extension CloudSaveMetadataValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CloudSaveMetadata, $Out> {
  CloudSaveMetadataCopyWith<$R, CloudSaveMetadata, $Out>
  get $asCloudSaveMetadata => $base.as(
    (v, t, t2) => _CloudSaveMetadataCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class CloudSaveMetadataCopyWith<
  $R,
  $In extends CloudSaveMetadata,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? slot,
    int? sizeBytes,
    DateTime? modifiedAt,
    String? deviceName,
  });
  CloudSaveMetadataCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CloudSaveMetadataCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CloudSaveMetadata, $Out>
    implements CloudSaveMetadataCopyWith<$R, CloudSaveMetadata, $Out> {
  _CloudSaveMetadataCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CloudSaveMetadata> $mapper =
      CloudSaveMetadataMapper.ensureInitialized();
  @override
  $R call({
    String? slot,
    Object? sizeBytes = $none,
    Object? modifiedAt = $none,
    Object? deviceName = $none,
  }) => $apply(
    FieldCopyWithData({
      if (slot != null) #slot: slot,
      if (sizeBytes != $none) #sizeBytes: sizeBytes,
      if (modifiedAt != $none) #modifiedAt: modifiedAt,
      if (deviceName != $none) #deviceName: deviceName,
    }),
  );
  @override
  CloudSaveMetadata $make(CopyWithData data) => CloudSaveMetadata(
    slot: data.get(#slot, or: $value.slot),
    sizeBytes: data.get(#sizeBytes, or: $value.sizeBytes),
    modifiedAt: data.get(#modifiedAt, or: $value.modifiedAt),
    deviceName: data.get(#deviceName, or: $value.deviceName),
  );

  @override
  CloudSaveMetadataCopyWith<$R2, CloudSaveMetadata, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CloudSaveMetadataCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class CloudSaveMapper extends ClassMapperBase<CloudSave> {
  CloudSaveMapper._();

  static CloudSaveMapper? _instance;
  static CloudSaveMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudSaveMapper._());
      CloudSaveMetadataMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'CloudSave';

  static CloudSaveMetadata _$metadata(CloudSave v) => v.metadata;
  static const Field<CloudSave, CloudSaveMetadata> _f$metadata = Field(
    'metadata',
    _$metadata,
  );
  static List<int> _$data(CloudSave v) => v.data;
  static const Field<CloudSave, List<int>> _f$data = Field('data', _$data);

  @override
  final MappableFields<CloudSave> fields = const {
    #metadata: _f$metadata,
    #data: _f$data,
  };

  static CloudSave _instantiate(DecodingData data) {
    return CloudSave(metadata: data.dec(_f$metadata), data: data.dec(_f$data));
  }

  @override
  final Function instantiate = _instantiate;

  static CloudSave fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CloudSave>(map);
  }

  static CloudSave fromJson(String json) {
    return ensureInitialized().decodeJson<CloudSave>(json);
  }
}

mixin CloudSaveMappable {
  String toJson() {
    return CloudSaveMapper.ensureInitialized().encodeJson<CloudSave>(
      this as CloudSave,
    );
  }

  Map<String, dynamic> toMap() {
    return CloudSaveMapper.ensureInitialized().encodeMap<CloudSave>(
      this as CloudSave,
    );
  }

  CloudSaveCopyWith<CloudSave, CloudSave, CloudSave> get copyWith =>
      _CloudSaveCopyWithImpl<CloudSave, CloudSave>(
        this as CloudSave,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CloudSaveMapper.ensureInitialized().stringifyValue(
      this as CloudSave,
    );
  }

  @override
  bool operator ==(Object other) {
    return CloudSaveMapper.ensureInitialized().equalsValue(
      this as CloudSave,
      other,
    );
  }

  @override
  int get hashCode {
    return CloudSaveMapper.ensureInitialized().hashValue(this as CloudSave);
  }
}

extension CloudSaveValueCopy<$R, $Out> on ObjectCopyWith<$R, CloudSave, $Out> {
  CloudSaveCopyWith<$R, CloudSave, $Out> get $asCloudSave =>
      $base.as((v, t, t2) => _CloudSaveCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CloudSaveCopyWith<$R, $In extends CloudSave, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  CloudSaveMetadataCopyWith<$R, CloudSaveMetadata, CloudSaveMetadata>
  get metadata;
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get data;
  $R call({CloudSaveMetadata? metadata, List<int>? data});
  CloudSaveCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CloudSaveCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CloudSave, $Out>
    implements CloudSaveCopyWith<$R, CloudSave, $Out> {
  _CloudSaveCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CloudSave> $mapper =
      CloudSaveMapper.ensureInitialized();
  @override
  CloudSaveMetadataCopyWith<$R, CloudSaveMetadata, CloudSaveMetadata>
  get metadata => $value.metadata.copyWith.$chain((v) => call(metadata: v));
  @override
  ListCopyWith<$R, int, ObjectCopyWith<$R, int, int>> get data => ListCopyWith(
    $value.data,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(data: v),
  );
  @override
  $R call({CloudSaveMetadata? metadata, List<int>? data}) => $apply(
    FieldCopyWithData({
      if (metadata != null) #metadata: metadata,
      if (data != null) #data: data,
    }),
  );
  @override
  CloudSave $make(CopyWithData data) => CloudSave(
    metadata: data.get(#metadata, or: $value.metadata),
    data: data.get(#data, or: $value.data),
  );

  @override
  CloudSaveCopyWith<$R2, CloudSave, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CloudSaveCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

