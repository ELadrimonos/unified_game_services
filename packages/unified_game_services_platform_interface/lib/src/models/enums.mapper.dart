// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'enums.dart';

class LeaderboardTimeScopeMapper extends EnumMapper<LeaderboardTimeScope> {
  LeaderboardTimeScopeMapper._();

  static LeaderboardTimeScopeMapper? _instance;
  static LeaderboardTimeScopeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaderboardTimeScopeMapper._());
    }
    return _instance!;
  }

  static LeaderboardTimeScope fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LeaderboardTimeScope decode(dynamic value) {
    switch (value) {
      case r'allTime':
        return LeaderboardTimeScope.allTime;
      case r'weekly':
        return LeaderboardTimeScope.weekly;
      case r'daily':
        return LeaderboardTimeScope.daily;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LeaderboardTimeScope self) {
    switch (self) {
      case LeaderboardTimeScope.allTime:
        return r'allTime';
      case LeaderboardTimeScope.weekly:
        return r'weekly';
      case LeaderboardTimeScope.daily:
        return r'daily';
    }
  }
}

extension LeaderboardTimeScopeMapperExtension on LeaderboardTimeScope {
  String toValue() {
    LeaderboardTimeScopeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LeaderboardTimeScope>(this)
        as String;
  }
}

class LeaderboardCollectionMapper extends EnumMapper<LeaderboardCollection> {
  LeaderboardCollectionMapper._();

  static LeaderboardCollectionMapper? _instance;
  static LeaderboardCollectionMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaderboardCollectionMapper._());
    }
    return _instance!;
  }

  static LeaderboardCollection fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LeaderboardCollection decode(dynamic value) {
    switch (value) {
      case r'global':
        return LeaderboardCollection.global;
      case r'friends':
        return LeaderboardCollection.friends;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LeaderboardCollection self) {
    switch (self) {
      case LeaderboardCollection.global:
        return r'global';
      case LeaderboardCollection.friends:
        return r'friends';
    }
  }
}

extension LeaderboardCollectionMapperExtension on LeaderboardCollection {
  String toValue() {
    LeaderboardCollectionMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LeaderboardCollection>(this)
        as String;
  }
}

class LeaderboardOrderMapper extends EnumMapper<LeaderboardOrder> {
  LeaderboardOrderMapper._();

  static LeaderboardOrderMapper? _instance;
  static LeaderboardOrderMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LeaderboardOrderMapper._());
    }
    return _instance!;
  }

  static LeaderboardOrder fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  LeaderboardOrder decode(dynamic value) {
    switch (value) {
      case r'highToLow':
        return LeaderboardOrder.highToLow;
      case r'lowToHigh':
        return LeaderboardOrder.lowToHigh;
      default:
        throw MapperException.unknownEnumValue(value);
    }
  }

  @override
  dynamic encode(LeaderboardOrder self) {
    switch (self) {
      case LeaderboardOrder.highToLow:
        return r'highToLow';
      case LeaderboardOrder.lowToHigh:
        return r'lowToHigh';
    }
  }
}

extension LeaderboardOrderMapperExtension on LeaderboardOrder {
  String toValue() {
    LeaderboardOrderMapper.ensureInitialized();
    return MapperContainer.globals.toValue<LeaderboardOrder>(this) as String;
  }
}

