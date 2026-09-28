class YtNormalizer {
  /// Safely extracts string text from YouTube objects ({text: ...}, runs: [...], or raw string)
  static String extractText(dynamic item, [String defaultValue = '']) {
    if (item == null) return defaultValue;
    if (item is String) return item;
    if (item is Map) {
      if (item['text'] != null && item['text'] is String) {
        return item['text'] as String;
      }
      if (item['runs'] != null && item['runs'] is List && (item['runs'] as List).isNotEmpty) {
        final firstRun = (item['runs'] as List).first;
        if (firstRun is Map && firstRun['text'] != null) {
          return firstRun['text'].toString();
        }
      }
    }
    return defaultValue;
  }

  /// Safely extracts best thumbnail URL from array or nested object
  static String? extractThumbnail(dynamic item) {
    if (item == null) return null;
    
    // Case 1: thumbnails is direct List [{url: ...}]
    if (item is List && item.isNotEmpty) {
      final last = item.last;
      if (last is Map && last['url'] != null) return last['url'].toString();
    }
    
    // Case 2: item is Map with contents or thumbnails
    if (item is Map) {
      if (item['contents'] != null) {
        return extractThumbnail(item['contents']);
      }
      if (item['thumbnails'] != null) {
        return extractThumbnail(item['thumbnails']);
      }
      if (item['url'] != null) {
        return item['url'].toString();
      }
    }

    return null;
  }

  /// Parses duration string like "4:22" or "1:02:15" to seconds integer
  static int parseDurationString(dynamic duration) {
    if (duration == null) return 0;
    if (duration is int) return duration;
    final text = extractText(duration);
    if (text.isEmpty) return 0;

    final parts = text.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    } else if (parts.length == 3) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      final s = int.tryParse(parts[2]) ?? 0;
      return (h * 3600) + (m * 60) + s;
    }
    return 0;
  }
}
