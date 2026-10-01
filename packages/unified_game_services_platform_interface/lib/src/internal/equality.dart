/// Deep-equality helpers for the hand-written model classes. Internal: not
/// exported from the package.
library;

/// Whether [a] and [b] hold equal elements in the same order.
bool listEquals<T>(List<T>? a, List<T>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether [a] and [b] hold the same keys mapped to equal values.
bool mapEquals<K, V>(Map<K, V>? a, Map<K, V>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || a[key] != b[key]) return false;
  }
  return true;
}

/// Order-sensitive hash consistent with [listEquals].
int listHash<T>(List<T> list) => Object.hashAll(list);

/// Order-insensitive hash consistent with [mapEquals].
int mapHash<K, V>(Map<K, V> map) => Object.hashAllUnordered(
  map.entries.map((e) => Object.hash(e.key, e.value)),
);
