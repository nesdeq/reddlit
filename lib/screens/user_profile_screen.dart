import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import '../models/post_feed.dart';
import '../models/reddit_user.dart';
import '../services/reddit_service.dart';
import '../services/settings_provider.dart';
import '../widgets/loading_widgets.dart';
import '../widgets/post_list_mixin.dart';
import '../widgets/post_list_view.dart';
import '../theme/app_theme.dart';
import '../theme/theme_helper.dart';
import '../utils/format_utils.dart';
import '../utils/haptics.dart';

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
    // Seed from cache so repeat visits show the profile with no spinner.
    final cachedUser = _redditService.peekUserInfo(widget.username);
    if (cachedUser != null) {
      _user = cachedUser;
      _isLoadingUser = false;
    }
    _loadUserInfo();
    loadPosts();
  }

  @override
  PostFeed get feed => UserFeed(widget.username);

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
              context.watch<SettingsProvider>().isFavoriteUser(widget.username)
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
            ),
            onPressed: () {
              Haptics.lightImpact();
              context.read<SettingsProvider>().toggleFavoriteUser(
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
          : PostListView(
              header: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
                child: _buildUserInfo(),
              ),
              posts: posts,
              isLoading: isLoading,
              hasMore: hasMore,
              errorMessage: loadError,
              scrollController: scrollController,
              onRefresh: loadPosts,
              onRetry: loadPosts,
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
