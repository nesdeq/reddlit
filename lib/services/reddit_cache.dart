/// Parsed pages by request URL, shown at once on a revisit while the page reloads.
class RedditCache {
  RedditCache._();
  static final RedditCache instance = RedditCache._();

  final Map<String, Object> _store = <String, Object>{};

  T? lookup<T>(String key) => _store[key] as T?;

  void put(String key, Object value) => _store[key] = value;

  /// Frees everything; the app calls this when the OS reports memory pressure.
  void clear() => _store.clear();
}
