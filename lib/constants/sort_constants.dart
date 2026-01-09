/// Sort options for posts and comments
class SortConstants {
  const SortConstants._(); // Private constructor to prevent instantiation
  // Post sort options (matching old.reddit.com)
  static const String hot = 'hot';
  static const String newSort = 'new';
  static const String rising = 'rising';
  static const String controversial = 'controversial';
  static const String top = 'top';

  // Top time periods
  static const String topHour = 'hour';
  static const String topDay = 'day';
  static const String topWeek = 'week';
  static const String topMonth = 'month';
  static const String topYear = 'year';
  static const String topAll = 'all';

  // Comment sort options
  static const String confidence = 'confidence'; // "Best" on Reddit UI

  // Display labels for post sorting
  static const Map<String, String> postSortLabels = {
    hot: 'Hot',
    newSort: 'New',
    rising: 'Rising',
    controversial: 'Controversial',
    top: 'Top',
  };

  // Display labels for comment sorting
  static const Map<String, String> commentSortLabels = {
    confidence: 'Best',
    top: 'Top',
    newSort: 'New',
    controversial: 'Controversial',
  };

  // Display labels for top time periods
  static const Map<String, String> topTimeLabels = {
    topHour: 'Past Hour',
    topDay: 'Past 24 Hours',
    topWeek: 'Past Week',
    topMonth: 'Past Month',
    topYear: 'Past Year',
    topAll: 'All Time',
  };
}
