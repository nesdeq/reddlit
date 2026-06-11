/// Utility functions for formatting numbers, time, and dates
class FormatUtils {
  const FormatUtils._(); // Private constructor to prevent instantiation

  /// Formats large numbers with K/M suffixes
  /// Examples: 1234 -> "1.2K", 1234567 -> "1.2M"
  static String formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }

  /// Formats time as relative time ago
  /// Examples: "5m", "2h", "3d", "1y"
  static String formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  /// Convert old.reddit's `data-timestamp` (epoch milliseconds, as a string)
  /// to DateTime. Returns the epoch on missing/garbage input.
  static DateTime fromRedditMillis(String? millis) {
    final ms = int.tryParse(millis ?? '') ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Convert an ISO-8601 timestamp (old.reddit `<time datetime=...>`) to
  /// DateTime. Falls back to the epoch on parse failure.
  static DateTime fromIso8601(String? iso) =>
      DateTime.tryParse(iso ?? '')?.toLocal() ??
      DateTime.fromMillisecondsSinceEpoch(0);

  /// Format date as "MMM yyyy" (e.g., "Jan 2024")
  static String formatMonthYear(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }
}
