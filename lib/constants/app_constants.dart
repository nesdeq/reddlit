/// Application-wide constants for magic numbers and thresholds
class AppConstants {
  const AppConstants._(); // Private constructor to prevent instantiation

  // Scroll and pagination
  static const double scrollLoadThreshold = 0.7; // Load more when 70% scrolled (preload early)

  // Comment display
  static const int commentAutoCollapseDepth = 5; // Auto-collapse at depth 5+
  static const int commentMaxIndentDepth = 4; // Max visual indentation depth
  static const double commentIndentStep = 10.0; // Horizontal px per depth level
  static const double threadLineWidth = 1.5;
  static const double threadLineOpacity = 0.45; // Flat — no depth-based fade

  // Opacity values
  static const double overlayOpacity = 0.5;
  static const double galleryIndicatorOpacity = 0.6;
  static const double videoOverlayOpacity = 0.3;
  static const double codeBackgroundOpacity = 0.3;

  // Default subreddit options (value, label)
  static const List<(String, String)> defaultSubredditOptions = [
    ('frontpage', '/r/Frontpage'),
    ('all', '/r/All'),
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
