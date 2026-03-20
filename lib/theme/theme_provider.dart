import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _defaultSubreddit = 'frontpage';
  Set<String> _favoriteSubreddits = {};
  String _openAiApiKey = '';
  String _summaryLanguage = 'English';
  bool _isApiKeyValid = false;
  SharedPreferences? _prefs;
  bool _isPrefsLoaded = false; // Track if preferences have loaded

  ThemeProvider() {
    _loadPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  String get defaultSubreddit => _defaultSubreddit;
  Set<String> get favoriteSubreddits => Set.unmodifiable(_favoriteSubreddits);
  String get openAiApiKey => _openAiApiKey;
  String get summaryLanguage => _summaryLanguage;
  bool get isApiKeyValid => _isApiKeyValid;
  bool get isPrefsLoaded => _isPrefsLoaded; // Expose loading state

  bool get isDarkMode {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }

  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _defaultSubreddit = _prefs?.getString('default_subreddit') ?? 'frontpage';
    final favoritesList = _prefs?.getStringList('favorite_subreddits') ?? [];
    _favoriteSubreddits = Set.from(favoritesList);
    _openAiApiKey = _prefs?.getString('openai_api_key') ?? '';
    _summaryLanguage = _prefs?.getString('summary_language') ?? 'English';
    _isApiKeyValid = _prefs?.getBool('openai_api_key_valid') ?? false;
    _isPrefsLoaded = true; // Mark as loaded
    notifyListeners(); // This will trigger listeners to reload with correct default
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.light) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  Future<void> setDefaultSubreddit(String subreddit) async {
    _defaultSubreddit = subreddit;
    await _prefs?.setString('default_subreddit', subreddit);
    notifyListeners();
  }

  bool isFavorite(String subreddit) {
    return _favoriteSubreddits.contains(subreddit);
  }

  Future<void> toggleFavorite(String subreddit) async {
    if (_favoriteSubreddits.contains(subreddit)) {
      _favoriteSubreddits.remove(subreddit);
    } else {
      _favoriteSubreddits.add(subreddit);
    }
    await _prefs?.setStringList('favorite_subreddits', _favoriteSubreddits.toList());
    notifyListeners();
  }

  Future<void> setOpenAiApiKey(String key) async {
    _openAiApiKey = key;
    await _prefs?.setString('openai_api_key', key);
    // Reset validation when key changes
    _isApiKeyValid = false;
    await _prefs?.setBool('openai_api_key_valid', false);
    notifyListeners();
  }

  /// Validate OpenAI API key by making a test request
  /// Returns error message if invalid, null if valid
  Future<String?> validateApiKey(String key) async {
    if (key.isEmpty) {
      return 'API key cannot be empty';
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {
          'Authorization': 'Bearer $key',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isApiKeyValid = true;
        await _prefs?.setBool('openai_api_key_valid', true);
        notifyListeners();
        return null; // Valid
      } else if (response.statusCode == 401) {
        _isApiKeyValid = false;
        await _prefs?.setBool('openai_api_key_valid', false);
        notifyListeners();
        return 'Invalid API key';
      } else {
        final body = json.decode(response.body);
        return body['error']?['message'] ?? 'Unknown error';
      }
    } catch (e) {
      return 'Connection error: $e';
    }
  }

  Future<void> setSummaryLanguage(String language) async {
    _summaryLanguage = language;
    await _prefs?.setString('summary_language', language);
    notifyListeners();
  }
}
