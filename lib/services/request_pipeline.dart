import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../constants/http_constants.dart';

/// Throttled, deduped, retrying HTTP client for reddit.com JSON endpoints.
///
/// Three behaviors keep the app under Reddit's anonymous-request throttle:
///   - concurrency cap (at most [_maxConcurrent] in flight)
///   - minimum dispatch spacing ([_minGap])
///   - retry with exponential backoff + jitter on 429 / 503 / network errors
///
/// Identical in-flight requests are coalesced so multiple widgets asking for
/// the same URL share one network call. Terminal failures return `null` —
/// callers decide how to surface "no data."
class RequestPipeline {
  RequestPipeline._();
  static final RequestPipeline instance = RequestPipeline._();

  static const int _maxConcurrent = 3;
  static const Duration _minGap = Duration(milliseconds: 250);
  static const int _maxRetries = 3;
  static const Duration _backoffBase = Duration(milliseconds: 800);
  static const int _jitterMaxMs = 300;

  final http.Client _client = http.Client();
  final Random _rng = Random();

  final Map<String, Future<dynamic>> _inFlight = {};
  final List<Completer<void>> _waiters = [];
  int _active = 0;
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<dynamic> getJson(Uri uri) {
    final key = uri.toString();
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _run(uri);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<dynamic> _run(Uri uri) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      await _acquireSlot();
      http.Response? response;
      try {
        response = await _client.get(
          uri,
          headers: HttpConstants.browserHeaders,
        );
      } catch (_) {
        _releaseSlot();
        if (attempt == _maxRetries) return null;
        await _backoff(attempt, null);
        continue;
      }
      _releaseSlot();

      if (response.statusCode == 200) {
        try {
          return json.decode(response.body);
        } catch (_) {
          return null;
        }
      }
      final transient =
          response.statusCode == 429 ||
          response.statusCode == 503 ||
          response.statusCode == 502 ||
          response.statusCode == 504;
      if (!transient) return null;
      if (attempt == _maxRetries) return null;
      await _backoff(attempt, response.headers['retry-after']);
    }
    return null;
  }

  Future<void> _acquireSlot() async {
    if (_active >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;

    final elapsed = DateTime.now().difference(_lastDispatch);
    if (elapsed < _minGap) {
      await Future.delayed(_minGap - elapsed);
    }
    _lastDispatch = DateTime.now();
  }

  void _releaseSlot() {
    _active--;
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    }
  }

  Future<void> _backoff(int attempt, String? retryAfterHeader) async {
    final retryAfter = retryAfterHeader == null
        ? null
        : int.tryParse(retryAfterHeader.trim());
    Duration wait;
    if (retryAfter != null) {
      wait = Duration(seconds: retryAfter);
    } else {
      final multiplier = 1 << attempt;
      final jitter = _rng.nextInt(_jitterMaxMs);
      wait = _backoffBase * multiplier + Duration(milliseconds: jitter);
    }
    await Future.delayed(wait);
  }
}
