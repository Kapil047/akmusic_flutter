import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../data/models/song_model.dart';

class LyricsSheet extends StatefulWidget {
  final SongModel song;

  const LyricsSheet({super.key, required this.song});

  static void show(BuildContext context, SongModel song) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LyricsSheet(song: song),
    );
  }

  @override
  State<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends State<LyricsSheet> {
  String? _lyrics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLyrics();
  }

  Future<void> _fetchLyrics() async {
    try {
      final client = ApiClient();
      final res = await client.dio.get('/lyrics/${widget.song.id}');
      final data = res.data;
      if (data is Map && data['data'] != null) {
        final raw = data['data'];
        String text = '';
        if (raw is String) {
          text = raw;
        } else if (raw is Map) {
          text = raw['description']?['runs']?[0]?['text'] ??
              raw['lyrics'] ??
              raw['text'] ??
              '';
        }
        if (text.trim().isNotEmpty) {
          setState(() {
            _lyrics = text;
            _isLoading = false;
          });
          return;
        }
      }
      setState(() {
        _lyrics = 'No lyrics found for this track 🎶';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load lyrics for this track';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const Icon(Icons.lyrics_rounded, color: Color(0xFF6C5CE7), size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    Text(
                      widget.song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          // Lyrics Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF6C5CE7)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white38)))
                    : SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            _lyrics ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              height: 1.8,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
