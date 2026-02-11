import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../services/article_summary_service.dart';
import '../screens/settings_screen.dart';

class ArticleSummaryWidget {
  const ArticleSummaryWidget._();

  /// Show article summary modal
  static Future<void> showSummary({
    required BuildContext context,
    required String url,
    required String title,
  }) async {
    final colors = ThemeHelper(context);
    final themeProvider = context.read<ThemeProvider>();
    final apiKey = themeProvider.openAiApiKey;
    final language = themeProvider.summaryLanguage;

    // Check if API key is set and valid
    if (apiKey.isEmpty || !themeProvider.isApiKeyValid) {
      _showApiKeyRequiredDialog(context, apiKey.isEmpty);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _LoadingDialog(colors: colors),
    );

    // Fetch and summarize
    final service = ArticleSummaryService();
    final summary = await service.summarizeArticle(
      url: url,
      apiKey: apiKey,
      language: language,
    );

    // Dismiss loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    // Show result
    if (context.mounted) {
      if (summary != null && summary.isNotEmpty) {
        _showSummaryDialog(context, title, summary, url);
      } else {
        _showErrorDialog(context);
      }
    }
  }

  static void _showApiKeyRequiredDialog(BuildContext context, bool isEmpty) {
    final colors = ThemeHelper(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surfaceColor,
        title: Text(
          isEmpty ? 'API Key Required' : 'API Key Not Validated',
          style: colors.theme.textTheme.titleLarge,
        ),
        content: Text(
          isEmpty
              ? 'Please set your OpenAI API key in Settings to use article summarization.'
              : 'Your API key needs to be validated. Please go to Settings and save your API key to validate it.',
          style: colors.theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            child: Text(
              'Open Settings',
              style: TextStyle(color: colors.accentColor),
            ),
          ),
        ],
      ),
    );
  }

  static void _showSummaryDialog(
    BuildContext context,
    String title,
    String summary,
    String url,
  ) {
    final colors = ThemeHelper(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusLarge),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(AppTheme.spacing4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppTheme.spacing4),
                    decoration: BoxDecoration(
                      color: colors.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: colors.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: AppTheme.spacing2),
                    Expanded(
                      child: Text(
                        'AI Summary',
                        style: colors.theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: colors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: AppTheme.spacing3),

                // Article title
                Text(
                  title,
                  style: colors.theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: AppTheme.spacing4),

                // Summary content
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: SelectableText(
                      summary,
                      style: colors.theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ),
                ),

                const SizedBox(height: AppTheme.spacing4),

                // Footer note
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacing3),
                  decoration: BoxDecoration(
                    color: colors.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.spacing2),
                      Expanded(
                        child: Text(
                          'AI-generated summary powered by GPT-5.2',
                          style: colors.theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static void _showErrorDialog(BuildContext context) {
    final colors = ThemeHelper(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surfaceColor,
        title: Text(
          'Failed to Summarize',
          style: colors.theme.textTheme.titleLarge,
        ),
        content: Text(
          'Could not fetch or summarize the article. The article might be behind a paywall, or the API request failed.',
          style: colors.theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: colors.accentColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  final ThemeHelper colors;

  const _LoadingDialog({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: colors.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.accentColor),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              'Fetching and summarizing article...',
              style: colors.theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              'This may take a moment',
              style: colors.theme.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
