import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../constants/http_constants.dart';
import 'auth_service.dart';

/// Reddit HTML fetcher: at most [maxConcurrent] requests in flight, paced by the `Retry-After` reddit sends, one retry on a transient failure.
class RequestPipeline {
  RequestPipeline._() : _client = http.Client(), _now = DateTime.now;

  /// Fresh, non-singleton instance with an injected HTTP client and clock, for tests.
  @visibleForTesting
  RequestPipeline.withClient(
    http.Client client, {
    this._now = DateTime.now,
  }) : _client = client;

  static final RequestPipeline instance = RequestPipeline._();

  /// A browser's per-host connection limit; the request headers present one.
  @visibleForTesting
  static const int maxConcurrent = 6;
  static const _transientStatuses = {429, 502, 503, 504};
  static const _redirectStatuses = {301, 302, 303, 307, 308};

  /// Same limit dart:io applies when it follows redirects.
  @visibleForTesting
  static const int maxRedirects = 5;

  final http.Client _client;
  final DateTime Function() _now;

  final Map<String, Future<String?>> _inFlight = {};
  final List<Completer<void>> _waiters = [];
  int _active = 0;

  /// End of the pause reddit last asked for through `Retry-After`.
  DateTime _notBefore = DateTime.fromMillisecondsSinceEpoch(0);

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
    for (final lastAttempt in const [false, true]) {
      final http.Response response;
      try {
        response = await _dispatch(() => _get(uri));
      } catch (_) {
        if (lastAttempt) return null;
        continue;
      }

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
      if (!_transientStatuses.contains(response.statusCode)) return null;
    }
    return null;
  }

  /// Where [uri] redirects to, from one paced request; null when it does not redirect or fails.
  Future<Uri?> getRedirect(Uri uri) async {
    try {
      return _redirectTarget(uri, await _dispatch(() => _send(uri)));
    } catch (_) {
      return null;
    }
  }

  /// Runs [send] in a slot once reddit's last `Retry-After` has passed, and notes the one it answers with.
  Future<http.Response> _dispatch(
    Future<http.Response> Function() send,
  ) async {
    await _acquireSlot();
    try {
      for (
        var wait = _notBefore.difference(_now());
        wait > Duration.zero;
        wait = _notBefore.difference(_now())
      ) {
        await Future<void>.delayed(wait);
      }
      final response = await send();
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      if (seconds != null && seconds > 0) {
        _notBefore = _now().add(Duration(seconds: seconds));
      }
      return response;
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
    if (_active < maxConcurrent) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
  }

  /// A waiting request inherits the slot, so the count in flight never passes [maxConcurrent].
  void _releaseSlot() {
    if (_waiters.isEmpty) {
      _active--;
    } else {
      _waiters.removeAt(0).complete();
    }
  }
}
