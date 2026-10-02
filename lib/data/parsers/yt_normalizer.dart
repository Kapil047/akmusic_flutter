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

  /// Upgrades any YouTube / Google CDN thumbnail to Ultra-HD (800x800 or 720p)
  static String? upgradeToHighRes(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    var hd = url.trim();

    // 1. Google Usercontent sizing upgrade (=w60-h60 -> =w800-h800)
    if (hd.contains('googleusercontent.com')) {
      hd = hd.replaceAll(RegExp(r'=w\d+-h\d+'), '=w800-h800');
      hd = hd.replaceAll(RegExp(r'=s\d+'), '=s800');
      if (!hd.contains('=w800-h800') && !hd.contains('=s800')) {
        hd = hd.contains('?') ? '$hd&w=800&h=800' : '$hd=w800-h800-l90-rj';
      }
    }

    // 2. YouTube standard video thumbnail upgrade
    if (hd.contains('i.ytimg.com/vi/')) {
      hd = hd.replaceAll('hqdefault.jpg', 'hq720.jpg').replaceAll('mqdefault.jpg', 'hq720.jpg');
    }

    return hd;
  }

  /// Safely extracts best thumbnail URL from array or nested object and upgrades to Ultra-HD
  static String? extractThumbnail(dynamic item) {
    if (item == null) return null;
    String? foundUrl;

    // Case 1: thumbnails is direct List [{url: ...}]
    if (item is List && item.isNotEmpty) {
      final last = item.last;
      if (last is Map && last['url'] != null) {
        foundUrl = last['url'].toString();
      } else if (item.first is Map && item.first['url'] != null) {
        foundUrl = item.first['url'].toString();
      }
    }

    // Case 2: item is Map with contents or thumbnails
    if (foundUrl == null && item is Map) {
      if (item['contents'] != null) {
        return extractThumbnail(item['contents']);
      }
      if (item['thumbnails'] != null) {
        return extractThumbnail(item['thumbnails']);
      }
      if (item['thumbnail'] != null) {
        return extractThumbnail(item['thumbnail']);
      }
      if (item['url'] != null) {
        foundUrl = item['url'].toString();
      }
    }

    if (foundUrl == null && item is String) {
      foundUrl = item;
    }

    return upgradeToHighRes(foundUrl);
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
