import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/haptics.dart';
import 'article_summary_service.dart';

const _kApiKeyStorage = 'openai_api_key';
const _kApiKeyValidPref = 'openai_api_key_valid';
const _kSummaryLanguagePref = 'summary_language';
const _kDefaultSubredditPref = 'default_subreddit';
const _kFavoritesPref = 'favorite_subreddits';
const _kFavoriteUsersPref = 'favorite_users';
const _kThemeModePref = 'theme_mode';
const _kHapticsPref = 'haptics_enabled';

/// On-device user settings: theme, haptics, default feed, favorites, and summaries.
class SettingsProvider extends ChangeNotifier {
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

  SettingsProvider() {
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

  /// API key from secure storage, migrating a legacy plaintext prefs copy on first run.
  Future<String> _loadApiKey() async {
    try {
      final secureValue = await _secureStorage.read(key: _kApiKeyStorage);
      if (secureValue != null && secureValue.isNotEmpty) return secureValue;
    } catch (_) {
      // Secure storage unavailable: fall back to the prefs copy.
    }
    final legacy = _prefs?.getString(_kApiKeyStorage) ?? '';
    if (legacy.isNotEmpty) {
      try {
        await _secureStorage.write(key: _kApiKeyStorage, value: legacy);
        await _prefs?.remove(_kApiKeyStorage);
      } catch (_) {
        // Migration failed: the legacy value stays usable.
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

  Future<void> toggleFavorite(String subreddit) =>
      _toggleInSet(_favoriteSubreddits, _kFavoritesPref, subreddit);

  bool isFavoriteUser(String username) =>
      _favoriteUsers.contains(username);

  Future<void> toggleFavoriteUser(String username) =>
      _toggleInSet(_favoriteUsers, _kFavoriteUsersPref, username);

  Future<void> _toggleInSet(
    Set<String> set,
    String prefsKey,
    String value,
  ) async {
    if (!set.remove(value)) set.add(value);
    await _prefs?.setStringList(prefsKey, set.toList());
    notifyListeners();
  }

  /// Null on success; an error when the secure write failed (the key still works in memory).
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
      error = 'Secure storage unavailable; key held in memory only: $e';
    }
    await _setApiKeyValid(false);
    return error;
  }

  Future<void> _setApiKeyValid(bool valid) async {
    _isApiKeyValid = valid;
    await _prefs?.setBool(_kApiKeyValidPref, valid);
    notifyListeners();
  }

  /// Checks [key] with OpenAI and records the verdict; null when valid, else the reason.
  Future<String?> validateApiKey(String key) async {
    if (key.isEmpty) return 'API key cannot be empty';
    final (:valid, :error) = await ArticleSummaryService().checkApiKey(key);
    if (valid != null) await _setApiKeyValid(valid);
    return error;
  }

  Future<void> setSummaryLanguage(String language) async {
    _summaryLanguage = language;
    await _prefs?.setString(_kSummaryLanguagePref, language);
    notifyListeners();
  }
}
