import 'dart:async';

/// Endpoint-type buckets. TTL is chosen per bucket in [RedditCache].
enum CacheBucket { postList, comments, userInfo, subredditSearch }

/// Outcome of a cache lookup. `isStale` means the value is still usable but
/// past its TTL — the caller should return it to the UI immediately AND kick
/// off a background refresh.
class CacheHit<T> {
  final T value;
  final bool isStale;
  const CacheHit(this.value, {required this.isStale});
}

/// LRU + TTL cache with stale-while-revalidate semantics.
///
/// Fresh hits return immediately. Stale hits (within [_staleMultiplier] × TTL)
/// return immediately AND trigger a single-flight background refresh. Beyond
/// the stale window, entries are evicted and callers refetch blocking.
class RedditCache {
  RedditCache._();
  static final RedditCache instance = RedditCache._();

  static const Map<CacheBucket, Duration> _ttl = {
    CacheBucket.postList: Duration(seconds: 90),
    CacheBucket.comments: Duration(seconds: 120),
    CacheBucket.userInfo: Duration(minutes: 15),
    CacheBucket.subredditSearch: Duration(minutes: 10),
  };

  static const int _staleMultiplier = 4;
  static const int _maxEntries = 200;

  final Map<String, _Entry> _store = <String, _Entry>{};
  final Set<String> _refreshing = <String>{};

  CacheHit<T>? lookup<T>(CacheBucket bucket, String key) {
    final entry = _store[key];
    if (entry == null) return null;

    final age = DateTime.now().difference(entry.storedAt);
    final ttl = _ttl[bucket]!;
    final staleLimit = ttl * _staleMultiplier;

    if (age > staleLimit) {
      _store.remove(key);
      return null;
    }

    _touch(key, entry);
    return CacheHit<T>(entry.value as T, isStale: age > ttl);
  }

  void put(String key, Object value) {
    _store[key] = _Entry(value, DateTime.now());
    _evictIfNeeded();
  }

  /// Run [fetch] in the background iff no refresh is already in flight for
  /// [key]. Stores the result on success and notifies [onResult].
  void backgroundRefresh<T>(
    String key,
    Future<T?> Function() fetch,
    void Function(T fresh)? onResult,
  ) {
    if (_refreshing.contains(key)) return;
    _refreshing.add(key);
    Future<void>(() async {
      try {
        final result = await fetch();
        if (result != null) {
          put(key, result as Object);
          if (onResult != null) onResult(result);
        }
      } finally {
        _refreshing.remove(key);
      }
    });
  }

  void _touch(String key, _Entry entry) {
    // LinkedHashMap preserves insertion order; re-insert = "most recent."
    _store.remove(key);
    _store[key] = entry;
  }

  void _evictIfNeeded() {
    while (_store.length > _maxEntries) {
      _store.remove(_store.keys.first);
    }
  }
}

class _Entry {
  final Object value;
  final DateTime storedAt;
  _Entry(this.value, this.storedAt);
}
