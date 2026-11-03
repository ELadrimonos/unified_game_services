/// Cache of Steam game names for the profile screen.
///
/// Names come from [lookup] (in the demo, `SteamProvider.getGameName`); an
/// unresolved id stays `null` and the UI falls back to a generic "In game".
class SteamGameNames {
  SteamGameNames(this.lookup);

  final Future<String?> Function(int appId) lookup;
  final Map<int, String?> _cache = {};

  /// The cached name for [appId], or `null` if unresolved or not yet fetched.
  String? operator [](int appId) => _cache[appId];

  /// Resolves every id in [appIds] that is not cached yet.
  Future<void> resolve(Iterable<int> appIds) async {
    final missing = appIds.toSet().where((id) => !_cache.containsKey(id));
    await Future.wait(
      missing.map((id) async {
        try {
          _cache[id] = await lookup(id);
        } catch (_) {
          _cache[id] = null;
        }
      }),
    );
  }
}
