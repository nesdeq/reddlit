import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:reddlit/services/settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> load(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    final settings = SettingsProvider();
    await settings.ready;
    return settings;
  }

  test('restores every persisted setting', () async {
    final s = await load({
      'theme_mode': 'dark',
      'default_subreddit': 'personal',
      'favorite_subreddits': ['dartlang'],
      'favorite_users': ['spez'],
      'summary_language': 'German',
      'openai_api_key_valid': true,
      'haptics_enabled': false,
      'openai_api_key': 'sk-legacy',
    });
    expect(s.themeMode, ThemeMode.dark);
    expect(s.defaultSubreddit, 'personal');
    expect(s.favoriteSubreddits, {'dartlang'});
    expect(s.favoriteUsers, {'spez'});
    expect(s.summaryLanguage, 'German');
    expect(s.isApiKeyValid, isTrue);
    expect(s.hapticsEnabled, isFalse);
    expect(s.openAiApiKey, 'sk-legacy');
  });

  test('defaults when nothing is stored', () async {
    final s = await load({});
    expect(s.themeMode, ThemeMode.system);
    expect(s.defaultSubreddit, 'frontpage');
    expect(s.favoriteSubreddits, isEmpty);
    expect(s.favoriteUsers, isEmpty);
    expect(s.summaryLanguage, 'English');
    expect(s.isApiKeyValid, isFalse);
    expect(s.hapticsEnabled, isTrue);
    expect(s.openAiApiKey, isEmpty);
  });

  test('writes each setting under its key', () async {
    final s = await load({});
    await s.setThemeMode(ThemeMode.light);
    await s.toggleFavorite('dartlang');
    await s.toggleFavoriteUser('spez');
    await s.setDefaultSubreddit('all');
    await s.setSummaryLanguage('French');
    await s.setHapticsEnabled(false);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'light');
    expect(prefs.getStringList('favorite_subreddits'), ['dartlang']);
    expect(prefs.getStringList('favorite_users'), ['spez']);
    expect(prefs.getString('default_subreddit'), 'all');
    expect(prefs.getString('summary_language'), 'French');
    expect(prefs.getBool('haptics_enabled'), isFalse);
  });

  group('validateApiKey', () {
    Future<(String?, bool)> check(MockClient client) async {
      final s = await load({});
      final error =
          await http.runWithClient(() => s.validateApiKey('sk-test'), () => client);
      return (error, s.isApiKeyValid);
    }

    test('asks OpenAI for the model list with the key; 200 is valid', () async {
      final result = await check(MockClient((request) async {
        expect(request.url.toString(), 'https://api.openai.com/v1/models');
        expect(request.headers['Authorization'], 'Bearer sk-test');
        return http.Response('{}', 200);
      }));
      expect(result, (null, true));
    });

    test('401 is invalid', () async {
      expect(await check(MockClient((_) async => http.Response('{}', 401))),
          ('Invalid API key', false));
    });

    test("other statuses report OpenAI's message and keep the verdict",
        () async {
      expect(
        await check(MockClient((_) async =>
            http.Response('{"error":{"message":"quota exceeded"}}', 429))),
        ('quota exceeded', false),
      );
    });

    test('a network failure is reported', () async {
      final (error, _) =
          await check(MockClient((_) async => throw Exception('offline')));
      expect(error, startsWith('Connection error:'));
    });

    test('an empty key is refused without a request', () async {
      final s = await load({});
      final error = await http.runWithClient(
        () => s.validateApiKey(''),
        () => MockClient((_) async => fail('no request expected')),
      );
      expect(error, 'API key cannot be empty');
    });
  });
}
