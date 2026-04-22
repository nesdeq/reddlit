import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/reddit_user.dart';
import '../models/reddit_post.dart';
import '../services/reddit_service.dart';
import '../widgets/post_card.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/post_list_mixin.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../theme/theme_provider.dart';
import '../utils/format_utils.dart';
import '../utils/haptics.dart';
import '../utils/navigation_helper.dart';

class UserProfileScreen extends StatefulWidget {
  final String username;

  const UserProfileScreen({
    super.key,
    required this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with PostListMixin {
  final RedditService _redditService = RedditService();

  RedditUser? _user;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    // Seed from cache synchronously — repeat visits show the profile
    // instantly with no spinner.
    final cachedUser = _redditService.peekUserInfo(widget.username);
    if (cachedUser != null) {
      _user = cachedUser;
      _isLoadingUser = false;
    }
    _loadUserInfo();
    loadPosts();
  }

  @override
  Future<List<RedditPost>> loadPostsImplementation({String? after}) {
    return _redditService.getUserPosts(widget.username, after: after);
  }

  @override
  List<RedditPost>? peekCachedPosts() =>
      _redditService.peekUserPosts(widget.username);

  Future<void> _loadUserInfo() async {
    final user = await _redditService.getUserInfo(widget.username);
    if (!mounted) return;
    setState(() {
      _user = user;
      _isLoadingUser = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: scrollToTop,
          child: Text('u/${widget.username}'),
        ),
        actions: [
          IconButton(
            icon: Icon(
              context.watch<ThemeProvider>().isFavoriteUser(widget.username)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () {
              Haptics.lightImpact();
              context.read<ThemeProvider>().toggleFavoriteUser(
                widget.username,
              );
            },
            tooltip: 'Favorite',
          ),
          const SizedBox(width: AppTheme.spacing1),
        ],
      ),
      body: _isLoadingUser
          ? LoadingWidgets.loadingIndicator(context)
          : RefreshIndicator(
              onRefresh: onRefresh,
              color: colors.accentColor,
              child: ListView(
                controller: scrollController,
                cacheExtent: MediaQuery.of(context).size.height * 0.5,
                children: [
                  // User info header
                  if (_user != null) _buildUserInfo(),

                  // Jony Ive: Remove divider, use whitespace
                  const SizedBox(height: AppTheme.spacing4),

                  // User posts
                  if (isLoading && posts.isEmpty)
                    LoadingWidgets.loadingIndicatorPadded(context)
                  else if (posts.isEmpty)
                    LoadingWidgets.emptyState(context, 'No posts yet')
                  else
                    ...posts.map(
                      (post) => PostCard(
                        key: ValueKey(post.id),
                        post: post,
                        onTap: () => NavigationHelper.navigateToPost(context, post),
                      ),
                    ),

                  if (isLoading && posts.isNotEmpty)
                    LoadingWidgets.loadingIndicatorPadded(context),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfo() {
    final colors = ThemeHelper(context);

    return Container(
      color: colors.surfaceColor,
      padding: const EdgeInsets.all(AppTheme.spacing6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'u/${_user!.name}',
            style: colors.theme.textTheme.displayMedium,
          ),
          const SizedBox(height: AppTheme.spacing4),
          _buildMainStats(),
          const SizedBox(height: AppTheme.spacing4),
          _buildKarmaBreakdown(),
        ],
      ),
    );
  }

  Widget _buildMainStats() {
    return Row(
      children: [
        _UserStat(
          label: 'Karma',
          value: FormatUtils.formatNumber(_user!.totalKarma),
        ),
        const SizedBox(width: AppTheme.spacing6),
        _UserStat(
          label: 'Joined',
          value: FormatUtils.formatMonthYear(_user!.created),
        ),
      ],
    );
  }

  Widget _buildKarmaBreakdown() {
    final colors = ThemeHelper(context);

    return Row(
      children: [
        Icon(Icons.arrow_upward_rounded, size: 16, color: colors.textSecondary),
        const SizedBox(width: AppTheme.spacing1),
        Text(
          '${FormatUtils.formatNumber(_user!.linkKarma)} post',
          style: colors.theme.textTheme.bodySmall,
        ),
        const SizedBox(width: AppTheme.spacing4),
        Icon(Icons.chat_bubble_outline_rounded, size: 16, color: colors.textSecondary),
        const SizedBox(width: AppTheme.spacing1),
        Text(
          '${FormatUtils.formatNumber(_user!.commentKarma)} comment',
          style: colors.theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Compact user stat widget (label + value)
class _UserStat extends StatelessWidget {
  final String label;
  final String value;

  const _UserStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = ThemeHelper(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: colors.theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(label, style: colors.theme.textTheme.bodySmall),
      ],
    );
  }
}
