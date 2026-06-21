import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// Thin signed client for the GameJolt Game API v1.2.
///
/// Every request carries `game_id`, `format=json`, and a `signature` —
/// `md5(fullRequestUrl + privateKey)` — appended last. Responses are wrapped in
/// a `{"response": {"success": "true", ...}}` envelope; this client unwraps it
/// and throws a [GameServiceException] when `success` is not `"true"`.
///
/// An [http.Client] can be injected for testing.
class GameJoltClient {
  GameJoltClient({
    required this.gameId,
    required this.privateKey,
    http.Client? httpClient,
    this.baseUrl = 'https://api.gamejolt.com/api/game/v1_2',
  }) : _http = httpClient ?? http.Client();

  /// The game's public id (from the GameJolt dashboard).
  final String gameId;

  /// The game's private key. Used only to compute signatures; never sent.
  final String privateKey;

  /// API root, without trailing slash.
  final String baseUrl;

  final http.Client _http;

  /// Performs a signed GET against [endpoint] (e.g. `/users/`) with [params].
  ///
  /// Null-valued params are dropped. Returns the unwrapped `response` object.
  ///
  /// When [throwOnFailure] is `false`, a `success != "true"` envelope is
  /// returned instead of throwing — useful for endpoints where failure is a
  /// meaningful answer (e.g. `/sessions/check/`). Inspect `response['success']`.
  Future<Map<String, dynamic>> get(
    String endpoint,
    Map<String, String?> params, {
    bool throwOnFailure = true,
  }) async {
    final uri = signedUri(endpoint, params);
    final http.Response res;
    try {
      res = await _http.get(uri);
    } catch (e) {
      throw NetworkException('GameJolt request failed: $endpoint', e);
    }
    return _unwrap(res, endpoint, throwOnFailure: throwOnFailure);
  }

  /// Builds the fully-signed [Uri] for [endpoint] + [params]. Exposed for
  /// testing the signature.
  Uri signedUri(String endpoint, Map<String, String?> params) {
    final merged = <String, String>{
      'game_id': gameId,
      for (final e in params.entries)
        if (e.value != null) e.key: e.value!,
      'format': 'json',
    };
    final query = merged.entries
        .map(
          (e) =>
              '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}',
        )
        .join('&');
    final base = '$baseUrl$endpoint?$query';
    final signature = md5.convert(utf8.encode('$base$privateKey')).toString();
    return Uri.parse('$base&signature=$signature');
  }

  Map<String, dynamic> _unwrap(
    http.Response res,
    String endpoint, {
    required bool throwOnFailure,
  }) {
    if (res.statusCode != 200) {
      throw NetworkException(
        'GameJolt $endpoint returned HTTP ${res.statusCode}.',
      );
    }
    final body = jsonDecode(res.body);
    if (body is! Map || body['response'] is! Map) {
      throw PlatformOperationException(
        'Unexpected GameJolt response for $endpoint.',
      );
    }
    final response = (body['response'] as Map).cast<String, dynamic>();
    final ok = response['success'] == 'true' || response['success'] == true;
    if (!ok && throwOnFailure) {
      throw PlatformOperationException(
        (response['message'] as String?) ?? 'GameJolt $endpoint failed.',
      );
    }
    return response;
  }

  /// Whether a `response` map reports success.
  static bool isSuccess(Map<String, dynamic> response) =>
      response['success'] == 'true' || response['success'] == true;

  /// Closes the underlying HTTP client.
  void close() => _http.close();
}
