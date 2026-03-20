import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../widgets/modal_widgets.dart';
import '../constants/app_constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  bool _apiKeyVisible = false;
  bool _isValidating = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: context.read<ThemeProvider>().openAiApiKey,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    final themeProvider = context.read<ThemeProvider>();

    // Save the key first
    await themeProvider.setOpenAiApiKey(key);

    if (key.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('API key cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // Validate the key
    setState(() => _isValidating = true);

    final error = await themeProvider.validateApiKey(key);

    if (!mounted) return;
    setState(() => _isValidating = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API key saved and validated'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid API key: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  static const _languages = [
    'English', 'German', 'Spanish', 'French', 'Italian', 'Portuguese',
    'Russian', 'Chinese', 'Japanese', 'Korean', 'Arabic', 'Hindi',
    'Dutch', 'Swedish', 'Polish', 'Turkish',
  ];

  void _showLanguageSelector() {
    final colors = ThemeHelper(context);
    final currentLanguage = context.read<ThemeProvider>().summaryLanguage;

    ModalWidgets.showBottomSheetModal(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Text(
            'Summary Language',
            style: colors.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        ..._languages.map((language) {
          return ModalWidgets.selectionListTile(
            context: context,
            label: language,
            isSelected: currentLanguage == language,
            onTap: () => _changeLanguage(language),
          );
        }),
      ],
    );
  }

  Future<void> _changeLanguage(String language) async {
    await context.read<ThemeProvider>().setSummaryLanguage(language);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _showDefaultSubredditDialog() {
    ModalWidgets.showDefaultSubredditModal(
      context: context,
      currentDefault: context.read<ThemeProvider>().defaultSubreddit,
      onSelected: _changeDefaultSubreddit,
    );
  }

  Future<void> _changeDefaultSubreddit(String value) async {
    await context.read<ThemeProvider>().setDefaultSubreddit(value);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);
    final provider = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // API Key Section
          _buildSectionHeader('Article Summarization'),
          Container(
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
                  controller: _apiKeyController,
                  obscureText: !_apiKeyVisible,
                  decoration: InputDecoration(
                    hintText: 'sk-...',
                    filled: true,
                    fillColor: colors.backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(color: colors.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(color: colors.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      borderSide: BorderSide(color: colors.accentColor, width: 2),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _apiKeyVisible ? Icons.visibility_off : Icons.visibility,
                        color: colors.textSecondary,
                      ),
                      onPressed: () {
                        setState(() {
                          _apiKeyVisible = !_apiKeyVisible;
                        });
                      },
                    ),
                  ),
                  style: colors.theme.textTheme.bodyMedium,
                  onSubmitted: (_) => _saveApiKey(),
                ),
                const SizedBox(height: AppTheme.spacing3),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isValidating ? null : _saveApiKey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                    ),
                    child: _isValidating
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
                // Validation status
                if (provider.openAiApiKey.isNotEmpty) ...[
                  const SizedBox(height: AppTheme.spacing2),
                  Row(
                    children: [
                      Icon(
                        provider.isApiKeyValid
                            ? Icons.check_circle
                            : Icons.error_outline,
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
          ),

          const SizedBox(height: 1),

          // Only show language selector if API key is valid
          Container(
            color: colors.surfaceColor,
            child: ListTile(
              title: const Text('Summary Language'),
              subtitle: Text(provider.summaryLanguage),
              trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
              onTap: provider.isApiKeyValid
                  ? _showLanguageSelector
                  : null,
              enabled: provider.isApiKeyValid,
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          // Appearance Section
          _buildSectionHeader('Appearance'),
          Container(
            color: colors.surfaceColor,
            child: ListTile(
              title: const Text('Dark Mode'),
              trailing: Switch(
                value: provider.isDarkMode,
                onChanged: (_) {
                  context.read<ThemeProvider>().toggleTheme();
                },
                activeTrackColor: colors.accentColor,
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          // Subreddit Settings Section
          _buildSectionHeader('Subreddit Settings'),
          Container(
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
                  trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                  onTap: _showDefaultSubredditDialog,
                ),
                Divider(height: 1, color: colors.dividerColor),
                ListTile(
                  title: const Text('Manage Favorites'),
                  subtitle: Text(
                    '${provider.favoriteSubreddits.length} subreddits',
                  ),
                  trailing: Icon(Icons.chevron_right, color: colors.textTertiary),
                  onTap: _showFavoritesManager,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing4),

          // About Section
          _buildSectionHeader('About'),
          Container(
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
                Text(
                  'Version 1.0.0',
                  style: colors.theme.textTheme.bodySmall,
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  'A minimalist Reddit reader with AI-powered article summarization',
                  style: colors.theme.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing6),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final colors = ThemeHelper(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing4,
        AppTheme.spacing3,
        AppTheme.spacing4,
        AppTheme.spacing2,
      ),
      child: Text(
        title.toUpperCase(),
        style: colors.theme.textTheme.labelMedium?.copyWith(
              color: colors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
      ),
    );
  }

  void _showFavoritesManager() {
    final colors = ThemeHelper(context);
    final favorites = context.read<ThemeProvider>().favoriteSubreddits.toList()..sort();

    ModalWidgets.showBottomSheetModal(
      context: context,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing4),
          child: Text(
            'Favorite Subreddits',
            style: colors.theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        if (favorites.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing6),
            child: Center(
              child: Text(
                'No favorites yet',
                style: colors.theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
              ),
            ),
          )
        else
          ...favorites.map((subreddit) => ListTile(
                title: Text('r/$subreddit'),
                trailing: IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.textSecondary),
                  onPressed: () {
                    context.read<ThemeProvider>().toggleFavorite(subreddit);
                  },
                ),
              )),
      ],
    );
  }
}
