import 'dart:typed_data';

import 'package:dart_mappable/dart_mappable.dart';

part 'cloud_save.mapper.dart';

/// Metadata describing a cloud save slot without its payload.
///
/// Returned by listing operations so callers can browse saves without
/// downloading their (potentially large) contents.
@MappableClass()
class CloudSaveMetadata with CloudSaveMetadataMappable {
  /// Caller-defined slot name identifying the save (e.g. "profile", "slot1").
  final String slot;

  /// Size of the stored payload in bytes, if known.
  final int? sizeBytes;

  /// When the save was last modified, if known.
  final DateTime? modifiedAt;

  /// Name of the device that wrote the save, if the provider tracks it.
  final String? deviceName;

  const CloudSaveMetadata({
    required this.slot,
    this.sizeBytes,
    this.modifiedAt,
    this.deviceName,
  });
}

/// A cloud save slot together with its payload.
///
/// The payload is stored as a `List<int>` so it survives JSON round-trips;
/// use [bytes] to read it as a [Uint8List].
@MappableClass()
class CloudSave with CloudSaveMappable {
  /// Metadata describing this save.
  final CloudSaveMetadata metadata;

  /// Raw save payload, one byte per element.
  final List<int> data;

  const CloudSave({required this.metadata, required this.data});

  /// Builds a save from raw [bytes].
  CloudSave.fromBytes({required this.metadata, required Uint8List bytes})
    : data = bytes;

  /// Convenience accessor for the slot name.
  String get slot => metadata.slot;

  /// The payload as a [Uint8List].
  Uint8List get bytes => Uint8List.fromList(data);
}
