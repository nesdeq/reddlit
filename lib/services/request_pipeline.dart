import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/http_constants.dart';
import 'auth_service.dart';

/// Reddit HTML fetcher: [_maxConcurrent] in flight, [minGap] apart, backoff retries on 502/503/504 and network errors.
class RequestPipeline {
  RequestPipeline._() : _client = http.Client(), _now = DateTime.now;

  /// Fresh, non-singleton instance with an injected HTTP client and clock, for tests.
  @visibleForTesting
  RequestPipeline.withClient(
    http.Client client, {
    this._now = DateTime.now,
  }) : _client = client;

  static final RequestPipeline instance = RequestPipeline._();

  static const int _maxConcurrent = 2;
  @visibleForTesting
  static const Duration minGap = Duration(milliseconds: 2000);
  static const int _maxRetries = 3;
  static const Duration _backoffBase = Duration(milliseconds: 800);
  static const int _jitterMaxMs = 300;
  static const _redirectStatuses = {301, 302, 303, 307, 308};

  /// Same limit dart:io applies when it follows redirects.
  @visibleForTesting
  static const int maxRedirects = 5;

  final http.Client _client;
  final DateTime Function() _now;
  final Random _rng = Random();

  final Map<String, Future<String?>> _inFlight = {};
  final List<Completer<void>> _waiters = [];
  int _active = 0;
  DateTime _lastDispatch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Fetch the raw HTML body for [uri]. Identical in-flight requests are
  /// coalesced. Returns `null` on terminal failure.
  Future<String?> getHtml(Uri uri) {
    final key = uri.toString();
    final existing = _inFlight[key];
    if (existing != null) return existing;

    final future = _run(uri);
    _inFlight[key] = future;
    future.whenComplete(() => _inFlight.remove(key));
    return future;
  }

  Future<String?> _run(Uri uri) async {
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      await _acquireSlot();
      http.Response? response;
      try {
        response = await _get(uri);
      } catch (_) {
        _releaseSlot();
        if (attempt == _maxRetries) return null;
        await _backoff(attempt, null);
        continue;
      }
      _releaseSlot();

      if (response.statusCode == 200) {
        if (looksBlocked(response.body)) {
          AuthService.instance.onBlocked();
          return null;
        }
        return response.body;
      }
      if (response.statusCode == 403) {
        AuthService.instance.onBlocked();
        return null;
      }
      final transient =
          response.statusCode == 502 ||
          response.statusCode == 503 ||
          response.statusCode == 504;
      if (!transient) return null;
      if (attempt == _maxRetries) return null;
      await _backoff(attempt, response.headers['retry-after']);
    }
    return null;
  }

  /// Where [uri] redirects to, from one throttled request; null when it does not redirect or fails.
  Future<Uri?> getRedirect(Uri uri) async {
    await _acquireSlot();
    try {
      return _redirectTarget(uri, await _send(uri));
    } catch (_) {
      return null;
    } finally {
      _releaseSlot();
    }
  }

  /// Follows redirects itself: dart:io reads a raw UTF-8 `Location` as latin1 and requests a mangled path.
  Future<http.Response> _get(Uri uri) async {
    for (var hop = 0; ; hop++) {
      final response = await _send(uri);
      final target = _redirectTarget(uri, response);
      if (target == null || hop == maxRedirects) return response;
      uri = target;
    }
  }

  Future<http.Response> _send(Uri uri) async {
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers.addAll(_headers(uri));
    return http.Response.fromStream(await _client.send(request));
  }

  static Uri? _redirectTarget(Uri uri, http.Response response) {
    final location = response.headers['location'];
    if (location == null || !_redirectStatuses.contains(response.statusCode)) {
      return null;
    }
    return uri.resolve(_asUtf8(location));
  }

  static String _asUtf8(String latin1Decoded) {
    try {
      return utf8.decode(latin1.encode(latin1Decoded));
    } on Object {
      return latin1Decoded;
    }
  }

  Map<String, String> _headers(Uri uri) {
    final headers = Map<String, String>.from(HttpConstants.browserHeaders);
    final cookie = AuthService.instance.cookieHeader;
    if (cookie != null &&
        cookie.isNotEmpty &&
        AuthService.isRedditHost(uri.host.toLowerCase())) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  @visibleForTesting
  static bool looksBlocked(String body) {
    // Content containers decide first: a quoted trigger phrase must not blank the page or wipe the session.
    final hasContent = body.contains('id="siteTable"') ||
        body.contains('commentarea') ||
        body.contains('data-testid="search-community"');
    if (hasContent) return false;
    return body.contains('blocked by network security') ||
        body.contains('Please try to login') ||
        body.contains('Please wait for verification');
  }

  Future<void> _acquireSlot() async {
    if (_active >= _maxConcurrent) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _active++;

    // Reserve the slot before waiting so requests that wait together are still spaced.
    final now = _now();
    final next = _lastDispatch.add(minGap);
    _lastDispatch = next.isAfter(now) ? next : now;
    if (_lastDispatch.isAfter(now)) {
      await Future<void>.delayed(_lastDispatch.difference(now));
    }
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
