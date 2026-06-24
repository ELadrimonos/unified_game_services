import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:unified_game_services_platform_interface/unified_game_services_platform_interface.dart';

import 'auth/auth_strategy.dart';

/// Thin authenticated client for the Google Play Games **REST Games API v1**
/// (`https://games.googleapis.com/games/v1`).
///
/// Every request carries a `Bearer` token from the injected [AuthStrategy]. On
/// a `401` the client forces one token refresh and retries the request once
/// before giving up with [NotSignedInException]. Google's error envelope
/// (`{"error": {"code", "message", "status"}}`) is mapped onto the
/// [GameServiceException] hierarchy.
///
/// An [http.Client] can be injected for testing.
class GamesRestClient {
  GamesRestClient({
    required AuthStrategy auth,
    http.Client? httpClient,
    this.baseUrl = 'https://games.googleapis.com/games/v1',
  }) : _auth = auth, // ignore: prefer_initializing_formals
       _http = httpClient ?? http.Client();

  /// API root, without a trailing slash.
  final String baseUrl;

  final AuthStrategy _auth;
  final http.Client _http;

  /// Performs an authenticated `GET` on [path] (e.g. `/players/me`) with
  /// optional [query], returning the decoded JSON object.
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  /// Performs an authenticated `POST` on [path] with optional [query],
  /// returning the decoded JSON object (empty map when the body is empty).
  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, String>? query,
  }) => _send('POST', path, query: query);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: (query == null || query.isEmpty) ? null : query);

    var res = await _dispatch(method, uri, forceRefresh: false);
    if (res.statusCode == 401) {
      // Token likely expired mid-flight: refresh once and retry.
      res = await _dispatch(method, uri, forceRefresh: true);
    }
    return _decode(res, path);
  }

  Future<http.Response> _dispatch(
    String method,
    Uri uri, {
    required bool forceRefresh,
  }) async {
    final String token;
    try {
      token = await _auth.getAccessToken(forceRefresh: forceRefresh);
    } on GameServiceException {
      rethrow;
    } catch (e) {
      throw SignInFailedException('Could not obtain an access token.', e);
    }
    final headers = {'Authorization': 'Bearer $token'};
    try {
      return method == 'POST'
          ? await _http.post(uri, headers: headers)
          : await _http.get(uri, headers: headers);
    } catch (e) {
      throw NetworkException('Games API request failed: ${uri.path}', e);
    }
  }

  Map<String, dynamic> _decode(http.Response res, String path) {
    if (res.statusCode == 401) {
      throw const NotSignedInException(
        'Google Play Games rejected the access token.',
      );
    }
    final body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final message =
          (body is Map && body['error'] is Map
                  ? body['error']['message']
                  : null)
              as String? ??
          'Games API $path returned HTTP ${res.statusCode}.';
      throw PlatformOperationException(message, code: '${res.statusCode}');
    }
    if (body == null) return const {};
    if (body is! Map) {
      throw PlatformOperationException(
        'Unexpected Games API response for $path.',
      );
    }
    return body.cast<String, dynamic>();
  }

  /// Closes the underlying HTTP client.
  void close() => _http.close();
}
