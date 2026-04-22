import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../utils/haptics.dart';

const _kApiKeyStorage = 'openai_api_key';
const _kApiKeyValidPref = 'openai_api_key_valid';
const _kSummaryLanguagePref = 'summary_language';
const _kDefaultSubredditPref = 'default_subreddit';
const _kFavoritesPref = 'favorite_subreddits';
const _kFavoriteUsersPref = 'favorite_users';
const _kThemeModePref = 'theme_mode';
const _kHapticsPref = 'haptics_enabled';

class ThemeProvider extends ChangeNotifier {
  static const _secureStorage = FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.system;
  String _defaultSubreddit = 'frontpage';
  Set<String> _favoriteSubreddits = {};
  Set<String> _favoriteUsers = {};
  String _openAiApiKey = '';
  String _summaryLanguage = 'English';
  bool _isApiKeyValid = false;
  bool _hapticsEnabled = true;
  SharedPreferences? _prefs;

  final Completer<void> _readyCompleter = Completer<void>();

  ThemeProvider() {
    _loadPreferences();
  }

  /// Resolves once preferences have finished loading.
  Future<void> get ready => _readyCompleter.future;

  ThemeMode get themeMode => _themeMode;
  String get defaultSubreddit => _defaultSubreddit;
  Set<String> get favoriteSubreddits => Set.unmodifiable(_favoriteSubreddits);
  Set<String> get favoriteUsers => Set.unmodifiable(_favoriteUsers);
  String get openAiApiKey => _openAiApiKey;
  String get summaryLanguage => _summaryLanguage;
  bool get isApiKeyValid => _isApiKeyValid;
  bool get hapticsEnabled => _hapticsEnabled;

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = _parseThemeMode(_prefs?.getString(_kThemeModePref));
    _defaultSubreddit =
        _prefs?.getString(_kDefaultSubredditPref) ?? 'frontpage';
    _favoriteSubreddits = Set.from(
      _prefs?.getStringList(_kFavoritesPref) ?? <String>[],
    );
    _favoriteUsers = Set.from(
      _prefs?.getStringList(_kFavoriteUsersPref) ?? <String>[],
    );
    _summaryLanguage = _prefs?.getString(_kSummaryLanguagePref) ?? 'English';
    _isApiKeyValid = _prefs?.getBool(_kApiKeyValidPref) ?? false;
    _hapticsEnabled = _prefs?.getBool(_kHapticsPref) ?? true;
    Haptics.enabled = _hapticsEnabled;
    _openAiApiKey = await _loadApiKey();

    _readyCompleter.complete();
    notifyListeners();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    _hapticsEnabled = enabled;
    Haptics.enabled = enabled;
    await _prefs?.setBool(_kHapticsPref, enabled);
    notifyListeners();
  }

  /// Read API key from secure storage, migrating from legacy plaintext prefs
  /// on first run if present.
  Future<String> _loadApiKey() async {
    try {
      final secureValue = await _secureStorage.read(key: _kApiKeyStorage);
      if (secureValue != null && secureValue.isNotEmpty) return secureValue;
    } catch (_) {
      // Secure storage unavailable (e.g. platform issue) — fall back to prefs.
    }
    final legacy = _prefs?.getString(_kApiKeyStorage) ?? '';
    if (legacy.isNotEmpty) {
      try {
        await _secureStorage.write(key: _kApiKeyStorage, value: legacy);
        await _prefs?.remove(_kApiKeyStorage);
      } catch (_) {
        // Migration failed — keep legacy value usable but don't crash.
      }
    }
    return legacy;
  }

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setString(_kThemeModePref, mode.name);
    notifyListeners();
  }

  Future<void> setDefaultSubreddit(String subreddit) async {
    _defaultSubreddit = subreddit;
    await _prefs?.setString(_kDefaultSubredditPref, subreddit);
    notifyListeners();
  }

  bool isFavorite(String subreddit) =>
      _favoriteSubreddits.contains(subreddit);

  Future<void> toggleFavorite(String subreddit) async {
    if (!_favoriteSubreddits.remove(subreddit)) {
      _favoriteSubreddits.add(subreddit);
    }
    await _prefs?.setStringList(
      _kFavoritesPref,
      _favoriteSubreddits.toList(),
    );
    notifyListeners();
  }

  bool isFavoriteUser(String username) =>
      _favoriteUsers.contains(username);

  Future<void> toggleFavoriteUser(String username) async {
    if (!_favoriteUsers.remove(username)) {
      _favoriteUsers.add(username);
    }
    await _prefs?.setStringList(
      _kFavoriteUsersPref,
      _favoriteUsers.toList(),
    );
    notifyListeners();
  }

  /// Returns null on success, or an error message if the secure write failed.
  /// The in-memory value is always updated so validation can still proceed,
  /// but the caller should warn the user that the key won't persist.
  Future<String?> setOpenAiApiKey(String key) async {
    _openAiApiKey = key;
    String? error;
    try {
      if (key.isEmpty) {
        await _secureStorage.delete(key: _kApiKeyStorage);
      } else {
        await _secureStorage.write(key: _kApiKeyStorage, value: key);
      }
    } catch (e) {
      error = 'Secure storage unavailable — key held in memory only: $e';
    }
    _isApiKeyValid = false;
    await _prefs?.setBool(_kApiKeyValidPref, false);
    notifyListeners();
    return error;
  }

  /// Validate OpenAI API key by making a test request.
  /// Returns error message if invalid, null if valid.
  Future<String?> validateApiKey(String key) async {
    if (key.isEmpty) return 'API key cannot be empty';

    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $key'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isApiKeyValid = true;
        await _prefs?.setBool(_kApiKeyValidPref, true);
        notifyListeners();
        return null;
      }
      if (response.statusCode == 401) {
        _isApiKeyValid = false;
        await _prefs?.setBool(_kApiKeyValidPref, false);
        notifyListeners();
        return 'Invalid API key';
      }
      final body = json.decode(response.body);
      return body['error']?['message'] ?? 'Unknown error';
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<void> setSummaryLanguage(String language) async {
    _summaryLanguage = language;
    await _prefs?.setString(_kSummaryLanguagePref, language);
    notifyListeners();
  }
}
