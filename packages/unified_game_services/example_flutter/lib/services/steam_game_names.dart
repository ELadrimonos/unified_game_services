import 'dart:convert';

import 'package:http/http.dart' as http;

/// Resolves Steam app ids to game names through the public Store API.
///
/// Steamworks only exposes the app id of what a friend is playing, not its
/// name. Lookups are cached for the life of the object; any failure (offline,
/// blocked by CORS on web, unknown id) resolves to `null` and is not retried.
class SteamGameNames {
  SteamGameNames({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  final Map<int, String?> _cache = {};

  /// The cached name for [appId], or `null` if unresolved or not yet fetched.
  String? operator [](int appId) => _cache[appId];

  /// Fetches the names of every id in [appIds] that is not cached yet.
  Future<void> resolve(Iterable<int> appIds) async {
    final missing = appIds.toSet().where((id) => !_cache.containsKey(id));
    await Future.wait(missing.map(_fetch));
  }

  Future<void> _fetch(int appId) async {
    _cache[appId] = null;
    try {
      final response = await _client
          .get(
            Uri.https('store.steampowered.com', '/api/appdetails', {
              'appids': '$appId',
              'filters': 'basic',
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final entry = body['$appId'] as Map<String, dynamic>?;
      if (entry?['success'] == true) {
        _cache[appId] =
            (entry!['data'] as Map<String, dynamic>)['name'] as String?;
      }
    } catch (_) {
      // Best effort: the UI falls back to a generic "In game".
    }
  }
}
