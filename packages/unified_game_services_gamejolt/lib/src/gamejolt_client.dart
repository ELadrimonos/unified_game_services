import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

/// A thin signed client for the GameJolt Game API v1.2.
///
/// Every request carries `game_id`, `format=json` and a `signature`, which is
/// `md5(fullRequestUrl + privateKey)` appended last. Responses are wrapped in a
/// `{"response": {"success": "true", ...}}` envelope; the client unwraps it and
/// throws a [GameServiceException] when `success` is not `"true"`.
///
/// All requests are sent as GET, as the Game API expects. An [http.Client] can
/// be injected for testing.
class GameJoltClient {
  /// Creates a client for the game identified by [gameId].
  ///
  /// [privateKey] signs requests and is never sent. [httpClient] defaults to a
  /// new [http.Client]; the client owns it and closes it in [close]. [baseUrl]
  /// overrides the API root, for example to target a test server.
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

  /// The API root, without a trailing slash.
  final String baseUrl;

  final http.Client _http;

  /// Performs a signed GET against [endpoint] (for example `/users/`) with
  /// [params].
  ///
  /// Parameters with a `null` value are dropped. Returns the unwrapped
  /// `response` object. Throws [NetworkException] when the request fails or the
  /// HTTP status is not 200, and [PlatformOperationException] when the body is
  /// not a Game API envelope or, with [throwOnFailure], reports failure.
  ///
  /// When [throwOnFailure] is `false`, a `success` that is not `"true"` is
  /// returned instead of throwing. This suits endpoints where failure is a
  /// meaningful answer, such as `/sessions/check/`; test it with [isSuccess].
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

  /// Builds the fully signed [Uri] for [endpoint] and [params].
  ///
  /// Exposed so tests can check the signature.
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

  /// Whether the unwrapped [response] reports `success`.
  static bool isSuccess(Map<String, dynamic> response) =>
      response['success'] == 'true' || response['success'] == true;

  /// Closes the underlying HTTP client, including one that was injected.
  void close() => _http.close();
}
