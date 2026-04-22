enum CacheBucket { postList, comments, userInfo, subredditSearch }

class RedditCache {
  RedditCache._();
  static final RedditCache instance = RedditCache._();

  static const Map<CacheBucket, Duration> _ttl = {
    CacheBucket.postList: Duration(seconds: 90),
    CacheBucket.comments: Duration(seconds: 120),
    CacheBucket.userInfo: Duration(minutes: 15),
    CacheBucket.subredditSearch: Duration(minutes: 10),
  };

  static const int _maxEntries = 200;

  final Map<String, _Entry> _store = <String, _Entry>{};

  T? lookup<T>(CacheBucket bucket, String key) {
    final entry = _store[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.storedAt);
    if (age > _ttl[bucket]!) {
      _store.remove(key);
      return null;
    }

    _touch(key, entry);
    return entry.value as T;
  }

  void put(String key, Object value) {
    _store[key] = _Entry(value, DateTime.now());
    while (_store.length > _maxEntries) {
      _store.remove(_store.keys.first);
    }
  }

  void _touch(String key, _Entry entry) {
    _store.remove(key);
    _store[key] = entry;
  }
}

class _Entry {
  final Object value;
  final DateTime storedAt;
  _Entry(this.value, this.storedAt);
}
