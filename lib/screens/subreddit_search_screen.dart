import 'dart:async';
import 'package:flutter/material.dart';
import '../models/subreddit.dart';
import '../services/reddit_service.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/navigation_helper.dart';
import '../widgets/loading_widgets.dart';

class SubredditSearchScreen extends StatefulWidget {
  const SubredditSearchScreen({super.key});

  @override
  State<SubredditSearchScreen> createState() => _SubredditSearchScreenState();
}

class _SubredditSearchScreenState extends State<SubredditSearchScreen> {
  final RedditService _redditService = RedditService();
  final TextEditingController _searchController = TextEditingController();

  List<Subreddit> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final results = await _redditService.searchSubreddits(query);

      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Scaffold(
      backgroundColor: colors.backgroundColor,
      appBar: AppBar(
        title: const Text('Search Subreddits'),
      ),
      body: Column(
        children: [
          // Search input
          Container(
            color: colors.surfaceColor,
            padding: const EdgeInsets.all(AppTheme.spacing4),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search subreddits by name...',
                prefixIcon: Icon(Icons.search_rounded, color: colors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: colors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _debounceTimer?.cancel();
                          setState(() {
                            _results = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.backgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing4,
                  vertical: AppTheme.spacing3,
                ),
              ),
              onChanged: (value) {
                setState(() {});
                // Auto-search after 1 second of no typing
                _debounceTimer?.cancel();
                if (value.trim().isNotEmpty) {
                  _debounceTimer = Timer(const Duration(seconds: 1), () {
                    _performSearch(value);
                  });
                } else {
                  setState(() {
                    _results = [];
                    _hasSearched = false;
                  });
                }
              },
              onSubmitted: _performSearch,
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeHelper colors) {
    if (_isLoading) {
      return LoadingWidgets.loadingIndicator(context);
    }

    if (!_hasSearched) {
      return LoadingWidgets.emptyState(
        context,
        'Type to search subreddits by name',
      );
    }

    if (_results.isEmpty) {
      return LoadingWidgets.emptyState(
        context,
        'No subreddits found',
      );
    }

    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final subreddit = _results[index];
        return _buildSubredditTile(subreddit, colors);
      },
    );
  }

  Widget _buildSubredditTile(Subreddit subreddit, ThemeHelper colors) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        NavigationHelper.navigateToSubreddit(context, subreddit.displayName);
      },
      child: Container(
        color: colors.surfaceColor,
        margin: const EdgeInsets.only(bottom: 1),
        padding: const EdgeInsets.all(AppTheme.spacing4),
        child: Row(
          children: [
            // Subreddit icon or placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colors.dividerColor,
                shape: BoxShape.circle,
              ),
              child: subreddit.iconUrl != null
                  ? ClipOval(
                      child: Image.network(
                        subreddit.iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildPlaceholderIcon(colors),
                      ),
                    )
                  : _buildPlaceholderIcon(colors),
            ),

            const SizedBox(width: AppTheme.spacing3),

            // Subreddit info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'r/${subreddit.displayName}',
                    style: colors.theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing1),

                  // Subscriber count
                  Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        size: 14,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(width: AppTheme.spacing1),
                      Text(
                        '${FormatUtils.formatNumber(subreddit.subscribers)} members',
                        style: colors.theme.textTheme.bodySmall,
                      ),
                    ],
                  ),

                  // Description (if available)
                  if (subreddit.description != null &&
                      subreddit.description!.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing1),
                    Text(
                      subreddit.description!,
                      style: colors.theme.textTheme.bodySmall?.copyWith(
                        color: colors.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(ThemeHelper colors) {
    return Center(
      child: Icon(
        Icons.forum_rounded,
        color: colors.textTertiary,
        size: 24,
      ),
    );
  }
}
