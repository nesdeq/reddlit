import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/modal_widgets.dart';
import '../widgets/login.dart';
import '../widgets/login_sheet.dart';
import '../services/auth_service.dart';
import '../utils/haptics.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _languages = [
    'English', 'German', 'Spanish', 'French', 'Italian', 'Portuguese',
    'Russian', 'Chinese', 'Japanese', 'Korean', 'Arabic', 'Hindi',
    'Dutch', 'Swedish', 'Polish', 'Turkish',
  ];

  static const _themeOptions = [
    ('system', 'System'),
    ('light', 'Light'),
    ('dark', 'Dark'),
  ];

  static String _themeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
    ThemeMode.system => 'System',
  };

  static ThemeMode _parseTheme(String value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  void _showLanguageSelector() {
    final provider = context.read<ThemeProvider>();
    ModalWidgets.showTitledSelection(
      context: context,
      title: 'Summary Language',
      options: _languages.map((l) => (l, l)).toList(),
      isSelected: (v) => provider.summaryLanguage == v,
      onSelected: provider.setSummaryLanguage,
    );
  }

  void _showDefaultSubredditDialog() {
    final provider = context.read<ThemeProvider>();
    ModalWidgets.showDefaultSubredditModal(
      context: context,
      currentDefault: provider.defaultSubreddit,
      onSelected: provider.setDefaultSubreddit,
    );
  }

  void _showThemeSelector() {
    final provider = context.read<ThemeProvider>();
    ModalWidgets.showTitledSelection(
      context: context,
      title: 'Theme',
      options: _themeOptions,
      isSelected: (v) => _parseTheme(v) == provider.themeMode,
      onSelected: (v) => provider.setThemeMode(_parseTheme(v)),
    );
  }

  static String _favoritesSubtitle(int subs, int users) {
    final parts = <String>[];
    if (subs > 0) parts.add('$subs subreddit${subs == 1 ? '' : 's'}');
    if (users > 0) parts.add('$users user${users == 1 ? '' : 's'}');
    return parts.isEmpty ? 'None yet' : parts.join(' · ');
  }

  void _showFavoritesManager() {
    ModalWidgets.showBottomSheetModal(
      context: context,
      children: const [_FavoritesManagerBody()],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final provider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Article Summarization'),
          const _ApiKeyCard(),

          const SizedBox(height: 1),
          Material(
            color: colors.surfaceColor,
            child: ListTile(
              title: const Text('Summary Language'),
              subtitle: Text(provider.summaryLanguage),
              trailing: Icon(Icons.chevron_right_rounded, color: colors.textTertiary),
              onTap: provider.isApiKeyValid ? _showLanguageSelector : null,
              enabled: provider.isApiKeyValid,
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          const _SectionHeader('Appearance'),
          Material(
            color: colors.surfaceColor,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Theme'),
                  subtitle: Text(_themeLabel(provider.themeMode)),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                  ),
                  onTap: _showThemeSelector,
                ),
                Divider(height: 1, color: colors.dividerColor),
                SwitchListTile(
                  title: const Text('Haptic Feedback'),
                  subtitle: const Text('Subtle tap responses on interactions'),
                  value: provider.hapticsEnabled,
                  activeTrackColor: colors.accentColor,
                  onChanged: (value) {
                    if (value) Haptics.lightImpact();
                    provider.setHapticsEnabled(value);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          const _SectionHeader('Subreddit Settings'),
          Material(
            color: colors.surfaceColor,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Default Subreddit'),
                  subtitle: Text(
                    AppConstants.getDefaultSubredditLabel(
                      provider.defaultSubreddit,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                  ),
                  onTap: _showDefaultSubredditDialog,
                ),
                Divider(height: 1, color: colors.dividerColor),
                ListTile(
                  title: const Text('Manage Favorites'),
                  subtitle: Text(
                    _favoritesSubtitle(
                      provider.favoriteSubreddits.length,
                      provider.favoriteUsers.length,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: colors.textTertiary,
                  ),
                  onTap: _showFavoritesManager,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          const _SectionHeader('Reddit Account'),
          const _AccountCard(),

          const SizedBox(height: AppTheme.spacing4),

          const _SectionHeader('About'),
          const _AboutCard(),

          const SizedBox(height: AppTheme.spacing6),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing4,
        AppTheme.spacing3,
        AppTheme.spacing4,
        AppTheme.spacing2,
      ),
      child: Text(title.toUpperCase(), style: _sectionHeaderStyle(context)),
    );
  }
}

TextStyle _sectionHeaderStyle(BuildContext context) {
  final colors = ThemeHelper(context);
  return colors.theme.textTheme.labelSmall!.copyWith(
    color: colors.textSecondary,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
  );
}

class _FavoritesManagerBody extends StatelessWidget {
  const _FavoritesManagerBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, provider, _) {
        final subs = provider.favoriteSubreddits.toList()..sort();
        final users = provider.favoriteUsers.toList()..sort();

        if (subs.isEmpty && users.isEmpty) {
          return LoadingWidgets.emptyState(context, 'No favorites yet');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subs.isNotEmpty)
              _FavoritesGroup(
                title: 'Subreddits',
                entries: subs,
                prefix: 'r/',
                onRemove: provider.toggleFavorite,
              ),
            if (subs.isNotEmpty && users.isNotEmpty)
              const SizedBox(height: AppTheme.spacing5),
            if (users.isNotEmpty)
              _FavoritesGroup(
                title: 'Users',
                entries: users,
                prefix: 'u/',
                onRemove: provider.toggleFavoriteUser,
              ),
          ],
        );
      },
    );
  }
}

class _FavoritesGroup extends StatelessWidget {
  final String title;
  final List<String> entries;
  final String prefix;
  final Future<void> Function(String) onRemove;

  const _FavoritesGroup({
    required this.title,
    required this.entries,
    required this.prefix,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing4,
            0,
            AppTheme.spacing4,
            AppTheme.spacing2,
          ),
          child: Text(title.toUpperCase(), style: _sectionHeaderStyle(context)),
        ),
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(height: 1, color: colors.dividerColor),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing4,
            ),
            title: Text('$prefix${entries[i]}'),
            trailing: IconButton(
              icon: Icon(
                Icons.delete_outline_rounded,
                color: colors.textSecondary,
              ),
              onPressed: () {
                Haptics.lightImpact();
                onRemove(entries[i]);
              },
              tooltip: 'Remove',
            ),
          ),
        ],
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    return Container(
      color: colors.surfaceColor,
      padding: const EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reddlit',
            style: colors.theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing1),
          Text('Version 1.0.0', style: colors.theme.textTheme.bodySmall),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            'A minimalist Reddit reader with AI-powered article summarization',
            style: colors.theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard();

  Future<void> _test(BuildContext context) async {
    final error = await AuthService.instance.validate();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Session works — you are logged in.')),
    );
  }

  void _copyToken(BuildContext context, String token) {
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session token copied to clipboard.')),
    );
  }

  void _showToken(BuildContext context, String token) {
    final colors = ThemeHelper(context);
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.surfaceColor,
        title: const Text('Reddit session token'),
        content: SingleChildScrollView(
          child: SelectableText(
            token,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              _copyToken(context, token);
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    return Material(
      color: colors.surfaceColor,
      child: ListenableBuilder(
        listenable: AuthService.instance,
        builder: (context, _) {
          final auth = AuthService.instance;
          final signedIn = auth.isAuthenticated;
          return Column(
            children: [
              ListTile(
                leading: Icon(
                  !signedIn
                      ? Icons.person_off_rounded
                      : (auth.validated
                          ? Icons.verified_rounded
                          : Icons.help_outline_rounded),
                  color: !signedIn
                      ? colors.textSecondary
                      : (auth.validated ? Colors.green : Colors.orange),
                ),
                title: Text(!signedIn
                    ? 'Not signed in'
                    : (auth.validated ? 'Session active' : 'Session saved')),
                subtitle: Text(!signedIn
                    ? 'Browsing anonymously. Sign in if your network is blocked.'
                    : (auth.validated
                        ? 'Verified logged in to Reddit.'
                        : 'Tap Test connection to verify it works.')),
              ),
              Divider(height: 1, color: colors.dividerColor),
              if (!signedIn) ...[
                ListTile(
                  title: const Text('Log in with Reddit'),
                  subtitle: Text(Login.webViewSupported
                      ? 'Opens Reddit sign-in inside the app.'
                      : 'Opens Reddit sign-in in your browser.'),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: colors.textTertiary),
                  onTap: () => Login.start(context),
                ),
                Divider(height: 1, color: colors.dividerColor),
                ListTile(
                  title: const Text('Paste session cookie'),
                  subtitle: const Text('Backup method'),
                  trailing: Icon(Icons.chevron_right_rounded,
                      color: colors.textTertiary),
                  onTap: () => LoginSheet.show(context),
                ),
              ] else ...[
                ListTile(
                  title: const Text('Test connection'),
                  trailing: auth.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.refresh_rounded, color: colors.textTertiary),
                  onTap: auth.busy ? null : () => _test(context),
                ),
                Divider(height: 1, color: colors.dividerColor),
                ListTile(
                  title: const Text('Session token'),
                  subtitle: Text(
                    auth.cookieHeader ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.copy_rounded, color: colors.textTertiary),
                    tooltip: 'Copy token',
                    onPressed: () =>
                        _copyToken(context, auth.cookieHeader ?? ''),
                  ),
                  onTap: () => _showToken(context, auth.cookieHeader ?? ''),
                ),
                Divider(height: 1, color: colors.dividerColor),
                ListTile(
                  title: Text('Log out',
                      style: TextStyle(color: colors.theme.colorScheme.error)),
                  onTap: () => AuthService.instance.logout(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ApiKeyCard extends StatefulWidget {
  const _ApiKeyCard();

  @override
  State<_ApiKeyCard> createState() => _ApiKeyCardState();
}

class _ApiKeyCardState extends State<_ApiKeyCard> {
  late final TextEditingController _controller;
  bool _visible = false;
  bool _validating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<ThemeProvider>().openAiApiKey,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _controller.text.trim();
    final provider = context.read<ThemeProvider>();
    final storageError = await provider.setOpenAiApiKey(key);

    if (storageError != null) {
      _snack(storageError, background: Colors.red, seconds: 5);
      return;
    }

    if (key.isEmpty) {
      _snack('API key cleared');
      return;
    }

    setState(() => _validating = true);
    final error = await provider.validateApiKey(key);
    if (!mounted) return;
    setState(() => _validating = false);

    if (error == null) {
      _snack('API key saved and validated', background: Colors.green);
    } else {
      _snack(
        'Invalid API key: $error',
        background: Colors.red,
        seconds: 4,
      );
    }
  }

  void _snack(String message, {Color? background, int seconds = 2}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: background,
        duration: Duration(seconds: seconds),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final provider = context.watch<ThemeProvider>();

    return Container(
      color: colors.surfaceColor,
      padding: const EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OpenAI API Key',
            style: colors.theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            'Required for article summarization. Get your API key from platform.openai.com',
            style: colors.theme.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing3),
          TextField(
            controller: _controller,
            obscureText: !_visible,
            decoration: InputDecoration(
              hintText: 'sk-...',
              filled: true,
              fillColor: colors.backgroundColor,
              border: _border(colors.dividerColor),
              enabledBorder: _border(colors.dividerColor),
              focusedBorder: _border(colors.accentColor, width: 2),
              suffixIcon: IconButton(
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: colors.textSecondary,
                ),
                onPressed: () => setState(() => _visible = !_visible),
              ),
            ),
            style: colors.theme.textTheme.bodyMedium,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: AppTheme.spacing3),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _validating ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: AppTheme.spacing3,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                ),
              ),
              child: _validating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save & Validate API Key'),
            ),
          ),
          if (provider.openAiApiKey.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing2),
            Row(
              children: [
                Icon(
                  provider.isApiKeyValid
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  size: 16,
                  color: provider.isApiKeyValid
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: AppTheme.spacing1),
                Text(
                  provider.isApiKeyValid
                      ? 'API key validated'
                      : 'API key not validated',
                  style: colors.theme.textTheme.bodySmall?.copyWith(
                    color: provider.isApiKeyValid
                        ? Colors.green
                        : Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
