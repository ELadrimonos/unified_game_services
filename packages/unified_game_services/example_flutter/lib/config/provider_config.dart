import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Parses a `unified=native` per-line mapping (the unified-id → provider-native
/// id table each provider takes). Blank lines and `#` comments are ignored.
Map<String, String> parseIdMap(String raw) {
  final out = <String, String>{};
  for (final line in raw.split('\n')) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#') || !t.contains('=')) continue;
    final i = t.indexOf('=');
    final k = t.substring(0, i).trim();
    final v = t.substring(i + 1).trim();
    if (k.isNotEmpty && v.isNotEmpty) out[k] = v;
  }
  return out;
}

/// Config shared by providers that map unified achievement/leaderboard ids to
/// their own native ids. Stored as raw multiline text so the form round-trips.
mixin _IdMaps {
  String get achievementIdsRaw;
  String get leaderboardIdsRaw;

  Map<String, String>? get achievementIds {
    final m = parseIdMap(achievementIdsRaw);
    return m.isEmpty ? null : m;
  }

  Map<String, String>? get leaderboardIds {
    final m = parseIdMap(leaderboardIdsRaw);
    return m.isEmpty ? null : m;
  }
}

class GameJoltConfig with _IdMaps {
  GameJoltConfig({
    this.enabled = false,
    this.gameId = '',
    this.privateKey = '',
    this.username = '',
    this.userToken = '',
    this.achievementIdsRaw = '',
    this.leaderboardIdsRaw = '',
  });

  bool enabled;
  String gameId;
  String privateKey;
  String username;
  String userToken;
  @override
  String achievementIdsRaw;
  @override
  String leaderboardIdsRaw;

  bool get isComplete =>
      gameId.isNotEmpty &&
      privateKey.isNotEmpty &&
      username.isNotEmpty &&
      userToken.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'gameId': gameId,
    'privateKey': privateKey,
    'username': username,
    'userToken': userToken,
    'achievementIdsRaw': achievementIdsRaw,
    'leaderboardIdsRaw': leaderboardIdsRaw,
  };

  factory GameJoltConfig.fromJson(Map<String, dynamic> j) => GameJoltConfig(
    enabled: j['enabled'] as bool? ?? false,
    gameId: j['gameId'] as String? ?? '',
    privateKey: j['privateKey'] as String? ?? '',
    username: j['username'] as String? ?? '',
    userToken: j['userToken'] as String? ?? '',
    achievementIdsRaw: j['achievementIdsRaw'] as String? ?? '',
    leaderboardIdsRaw: j['leaderboardIdsRaw'] as String? ?? '',
  );
}

class SteamConfig with _IdMaps {
  SteamConfig({
    this.enabled = false,
    this.appId = '',
    this.achievementIdsRaw = '',
    this.leaderboardIdsRaw = '',
  });

  bool enabled;

  /// Steam AppId. Optional if a `steam_appid.txt` sits next to the executable.
  String appId;
  @override
  String achievementIdsRaw;
  @override
  String leaderboardIdsRaw;

  int? get appIdValue => appId.isEmpty ? null : int.tryParse(appId.trim());

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'appId': appId,
    'achievementIdsRaw': achievementIdsRaw,
    'leaderboardIdsRaw': leaderboardIdsRaw,
  };

  factory SteamConfig.fromJson(Map<String, dynamic> j) => SteamConfig(
    enabled: j['enabled'] as bool? ?? false,
    appId: j['appId'] as String? ?? '',
    achievementIdsRaw: j['achievementIdsRaw'] as String? ?? '',
    leaderboardIdsRaw: j['leaderboardIdsRaw'] as String? ?? '',
  );
}

class GooglePlayConfig with _IdMaps {
  GooglePlayConfig({
    this.enabled = false,
    this.oauthClientId = '',
    this.oauthClientSecret = '',
    this.achievementIdsRaw = '',
    this.leaderboardIdsRaw = '',
  });

  bool enabled;

  /// Desktop-app OAuth client id, used by the loopback flow off-Android. On
  /// Android the native client brokers the token, so this can be left blank.
  String oauthClientId;
  String oauthClientSecret;
  @override
  String achievementIdsRaw;
  @override
  String leaderboardIdsRaw;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'oauthClientId': oauthClientId,
    'oauthClientSecret': oauthClientSecret,
    'achievementIdsRaw': achievementIdsRaw,
    'leaderboardIdsRaw': leaderboardIdsRaw,
  };

  factory GooglePlayConfig.fromJson(Map<String, dynamic> j) => GooglePlayConfig(
    enabled: j['enabled'] as bool? ?? false,
    oauthClientId: j['oauthClientId'] as String? ?? '',
    oauthClientSecret: j['oauthClientSecret'] as String? ?? '',
    achievementIdsRaw: j['achievementIdsRaw'] as String? ?? '',
    leaderboardIdsRaw: j['leaderboardIdsRaw'] as String? ?? '',
  );
}

class EpicConfig with _IdMaps {
  EpicConfig({
    this.enabled = false,
    this.productId = '',
    this.sandboxId = '',
    this.deploymentId = '',
    this.clientId = '',
    this.clientSecret = '',
    this.encryptionKey = '',
    this.devAuthHost = '',
    this.devAuthCredentialName = '',
    this.achievementIdsRaw = '',
    this.leaderboardIdsRaw = '',
  });

  bool enabled;
  String productId;
  String sandboxId;
  String deploymentId;
  String clientId;
  String clientSecret;

  /// 64 hex chars. Required for cloud save (PDS encrypts at rest).
  String encryptionKey;

  /// Developer Auth Tool endpoint (`host:port`) + credential name — the
  /// recommended EAS login during development.
  String devAuthHost;
  String devAuthCredentialName;
  @override
  String achievementIdsRaw;
  @override
  String leaderboardIdsRaw;

  bool get isComplete =>
      productId.isNotEmpty &&
      sandboxId.isNotEmpty &&
      deploymentId.isNotEmpty &&
      clientId.isNotEmpty &&
      clientSecret.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'productId': productId,
    'sandboxId': sandboxId,
    'deploymentId': deploymentId,
    'clientId': clientId,
    'clientSecret': clientSecret,
    'encryptionKey': encryptionKey,
    'devAuthHost': devAuthHost,
    'devAuthCredentialName': devAuthCredentialName,
    'achievementIdsRaw': achievementIdsRaw,
    'leaderboardIdsRaw': leaderboardIdsRaw,
  };

  factory EpicConfig.fromJson(Map<String, dynamic> j) => EpicConfig(
    enabled: j['enabled'] as bool? ?? false,
    productId: j['productId'] as String? ?? '',
    sandboxId: j['sandboxId'] as String? ?? '',
    deploymentId: j['deploymentId'] as String? ?? '',
    clientId: j['clientId'] as String? ?? '',
    clientSecret: j['clientSecret'] as String? ?? '',
    encryptionKey: j['encryptionKey'] as String? ?? '',
    devAuthHost: j['devAuthHost'] as String? ?? '',
    devAuthCredentialName: j['devAuthCredentialName'] as String? ?? '',
    achievementIdsRaw: j['achievementIdsRaw'] as String? ?? '',
    leaderboardIdsRaw: j['leaderboardIdsRaw'] as String? ?? '',
  );
}

/// Aggregated config for all providers, persisted to a single
/// shared_preferences key. Secrets stay on-device — nothing is committed.
class AppConfig {
  AppConfig({
    GameJoltConfig? gameJolt,
    SteamConfig? steam,
    GooglePlayConfig? googlePlay,
    EpicConfig? epic,
  }) : gameJolt = gameJolt ?? GameJoltConfig(),
       steam = steam ?? SteamConfig(),
       googlePlay = googlePlay ?? GooglePlayConfig(),
       epic = epic ?? EpicConfig();

  final GameJoltConfig gameJolt;
  final SteamConfig steam;
  final GooglePlayConfig googlePlay;
  final EpicConfig epic;

  static const _key = 'unified_demo.config.v1';

  Map<String, dynamic> toJson() => {
    'gameJolt': gameJolt.toJson(),
    'steam': steam.toJson(),
    'googlePlay': googlePlay.toJson(),
    'epic': epic.toJson(),
  };

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
    gameJolt: GameJoltConfig.fromJson(
      (j['gameJolt'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    steam: SteamConfig.fromJson(
      (j['steam'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    googlePlay: GooglePlayConfig.fromJson(
      (j['googlePlay'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
    epic: EpicConfig.fromJson(
      (j['epic'] as Map?)?.cast<String, dynamic>() ?? const {},
    ),
  );

  static Future<AppConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return AppConfig();
    try {
      return AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppConfig();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(toJson()));
  }
}
