/// @docImport '../platform_interface/platform_interface.dart';
library;

import 'dart:typed_data';

import '../internal/equality.dart';

/// Metadata describing a cloud save slot without its payload.
///
/// Returned by [UnifiedGameServicesPlatform.listSaves] so callers can browse
/// saves without downloading their (potentially large) contents.
class CloudSaveMetadata {
  /// Caller-defined slot name identifying the save (e.g. "profile", "slot1").
  ///
  /// This is the `slot` argument of [UnifiedGameServicesPlatform.saveData].
  final String slot;

  /// Size of the stored payload in bytes, if known.
  final int? sizeBytes;

  /// When the save was last modified, if known.
  final DateTime? modifiedAt;

  /// Name of the device that wrote the save, if the provider tracks it.
  final String? deviceName;

  /// [UnifiedGameServicesPlatform.providerId] of the provider this came from.
  ///
  /// Set by the `UnifiedGameServices` facade on reads; `null` when the object
  /// was built by a provider or by hand.
  final String? providerId;

  /// Creates metadata for the save in [slot].
  ///
  /// [sizeBytes], [modifiedAt] and [deviceName] are `null` when the provider
  /// does not report them.
  const CloudSaveMetadata({
    required this.slot,
    this.sizeBytes,
    this.modifiedAt,
    this.deviceName,
    this.providerId,
  });

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  CloudSaveMetadata copyWith({
    String? slot,
    int? sizeBytes,
    DateTime? modifiedAt,
    String? deviceName,
    String? providerId,
  }) => CloudSaveMetadata(
    slot: slot ?? this.slot,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    modifiedAt: modifiedAt ?? this.modifiedAt,
    deviceName: deviceName ?? this.deviceName,
    providerId: providerId ?? this.providerId,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudSaveMetadata &&
          other.slot == slot &&
          other.sizeBytes == sizeBytes &&
          other.modifiedAt == modifiedAt &&
          other.deviceName == deviceName &&
          other.providerId == providerId;

  @override
  int get hashCode =>
      Object.hash(slot, sizeBytes, modifiedAt, deviceName, providerId);

  @override
  String toString() =>
      'CloudSaveMetadata(slot: $slot, sizeBytes: $sizeBytes, '
      'modifiedAt: $modifiedAt, deviceName: $deviceName, '
      'providerId: $providerId)';
}

/// A cloud save slot together with its payload.
///
/// Returned by [UnifiedGameServicesPlatform.loadData]. The payload is stored
/// as a `List<int>`; use [bytes] to read it as a [Uint8List].
class CloudSave {
  /// Metadata describing this save.
  final CloudSaveMetadata metadata;

  /// Raw save payload, one byte per element.
  final List<int> data;

  /// Creates a save from its [metadata] and raw [data].
  const CloudSave({required this.metadata, required this.data});

  /// Creates a save from its [metadata] and raw [bytes].
  ///
  /// The [bytes] are kept as [data] without copying.
  CloudSave.fromBytes({required this.metadata, required Uint8List bytes})
    : data = bytes;

  /// The slot name, shorthand for [CloudSaveMetadata.slot] of [metadata].
  String get slot => metadata.slot;

  /// The payload as a [Uint8List].
  ///
  /// Copies [data] on every access; cache the result when reading repeatedly.
  Uint8List get bytes => Uint8List.fromList(data);

  /// Returns a copy with the given fields replaced.
  ///
  /// A `null` argument keeps the current value, so a field cannot be reset to
  /// `null` through this method; build a new instance for that.
  CloudSave copyWith({CloudSaveMetadata? metadata, List<int>? data}) =>
      CloudSave(metadata: metadata ?? this.metadata, data: data ?? this.data);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CloudSave &&
          other.metadata == metadata &&
          listEquals(other.data, data);

  @override
  int get hashCode => Object.hash(metadata, listHash(data));

  /// Prints the payload size, not its contents.
  @override
  String toString() =>
      'CloudSave(metadata: $metadata, data: ${data.length} bytes)';
}
