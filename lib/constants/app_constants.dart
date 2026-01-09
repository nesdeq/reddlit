/// Application-wide constants for magic numbers and thresholds
class AppConstants {
  const AppConstants._(); // Private constructor to prevent instantiation

  // Scroll and pagination
  static const double scrollLoadThreshold = 0.7; // Load more when 70% scrolled (preload early)

  // Comment display
  static const int commentAutoCollapseDepth = 3; // Auto-collapse comments at depth 3+
  static const int commentMaxIndentDepth = 3; // Max visual indentation depth

  // Opacity values
  static const double threadLineBaseOpacity = 1.0;
  static const double threadLineOpacityDecrement = 0.08; // Decrease per depth level
  static const double threadLineMinOpacity = 0.3;
  static const double overlayOpacity = 0.5;
  static const double galleryIndicatorOpacity = 0.6;
  static const double videoOverlayOpacity = 0.3;
  static const double codeBackgroundOpacity = 0.3;

  // Default subreddit options (value, label)
  static const List<(String, String)> defaultSubredditOptions = [
    ('frontpage', '/r/Frontpage'),
    ('all', '/r/All'),
    ('de', '/r/DE'),
    ('personal', 'Personal Selection'),
  ];

  /// Get display label for a default subreddit value
  static String getDefaultSubredditLabel(String value) {
    for (final option in defaultSubredditOptions) {
      if (option.$1 == value) return option.$2;
    }
    return value;
  }
}
