import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../constants/http_constants.dart';

class AuthService extends ChangeNotifier {
  AuthService._()
      : _client = http.Client(),
        _storage = const FlutterSecureStorage();

  /// Fresh, non-singleton instance with an injected HTTP client, for tests.
  @visibleForTesting
  AuthService.withClient(http.Client client)
      : _client = client,
        _storage = const FlutterSecureStorage();

  static final AuthService instance = AuthService._();

  final http.Client _client;
  final FlutterSecureStorage _storage;
  static const _kCookie = 'reddit_session_cookie';
  static const _timeout = Duration(seconds: 20);

  String? _cookie;
  bool _needsLogin = false;
  bool _busy = false;
  bool _validated = false;

  String? get cookieHeader => _cookie;
  bool get isAuthenticated => _cookie != null && _cookie!.isNotEmpty;
  bool get needsLogin => _needsLogin;
  bool get busy => _busy;
  bool get validated => _validated;

  Future<void> load() async {
    try {
      _cookie = await _storage.read(key: _kCookie);
    } catch (_) {}
    notifyListeners();
  }

  void onBlocked() {
    if (_cookie != null) {
      _cookie = null;
      _validated = false;
      _storage.delete(key: _kCookie).catchError((_) {});
    }
    if (!_needsLogin) {
      _needsLogin = true;
      notifyListeners();
    }
  }

  Future<String?> setSession(String cookieHeader) => _store(cookieHeader.trim());

  Future<String?> submitSessionCookie(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return Future.value('Paste your reddit_session cookie.');
    final cookie =
        input.contains('reddit_session=') ? input : 'reddit_session=$input';
    return _store(cookie);
  }

  Future<String?> validate() {
    final cookie = _cookie;
    if (cookie == null || cookie.isEmpty) {
      return Future.value('No session saved.');
    }
    return _withBusyGuard(() async {
      _validated = await _check(cookie);
      return _validated ? null : 'Session is not active. Log in again.';
    });
  }

  Future<void> logout() async {
    _cookie = null;
    _validated = false;
    try {
      await _storage.delete(key: _kCookie);
    } catch (_) {}
    notifyListeners();
  }

  Map<String, String> mediaHeaders(String url) {
    final headers = <String, String>{
      'User-Agent': HttpConstants.userAgent,
      'Accept-Language': 'en-US,en;q=0.9',
      'Referer': 'https://old.reddit.com/',
    };
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    final cookie = _cookie;
    if (cookie != null && cookie.isNotEmpty && isRedditHost(host)) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  Future<String?> _store(String cookie) {
    if (cookie.isEmpty || !cookie.contains('reddit_session=')) {
      return Future.value('No reddit_session found in that value.');
    }
    return _withBusyGuard(() async {
      if (!await _check(cookie)) {
        return 'That session is not logged in to Reddit. Try again.';
      }
      _cookie = cookie;
      _validated = true;
      _needsLogin = false;
      try {
        await _storage.write(key: _kCookie, value: cookie);
      } catch (_) {}
      return null;
    });
  }

  /// Toggle [busy] around [action], mapping timeouts and errors to the
  /// user-facing strings shared by every network-touching auth call.
  Future<String?> _withBusyGuard(Future<String?> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } on TimeoutException {
      return 'Timed out reaching Reddit.';
    } catch (e) {
      return 'Error: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> _check(String cookie) async {
    final resp = await _client.get(
      Uri.parse('https://old.reddit.com/'),
      headers: {...HttpConstants.browserHeaders, 'Cookie': cookie},
    ).timeout(_timeout);
    return resp.statusCode == 200 && resp.body.contains('loggedin');
  }

  /// Hosts the session cookie may be sent to.
  static bool isRedditHost(String host) {
    const roots = ['redd.it', 'reddit.com', 'redditmedia.com', 'redditstatic.com'];
    for (final r in roots) {
      if (host == r || host.endsWith('.$r')) return true;
    }
    return false;
  }
}
