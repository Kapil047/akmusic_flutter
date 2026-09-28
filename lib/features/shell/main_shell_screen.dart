import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'mini_player_bar.dart';
import '../../player/player_controller.dart';
import '../../data/models/song_model.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 1. Home Tab
          _buildHomeDemoTab(),
          // 2. Search Tab
          _buildPlaceholderTab('Search Songs, Artists, Albums', Icons.search_rounded),
          // 3. Library Tab
          _buildPlaceholderTab('Your Library (Favorites & Playlists)', Icons.library_music_rounded),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayerBar(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHomeDemoTab() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Discover Music', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('Tap any track to test background streaming engine', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 20),

          // Test Song 1: Kesariya
          _buildTestSongCard(
            const SongModel(
              id: 'NJAv_7lHUIU',
              title: 'Kesariya (From "Brahmastra")',
              artist: 'Arijit Singh, Pritam',
              album: 'Brahmastra',
              thumbnailUrl: 'https://yt3.googleusercontent.com/CH0SThQN0HOk2eV81GGA-Tiftn58G48iy8lEyKNXJjbDSI9ApKKnmt4ncwr5gO_mZoQvFF3HPfHtky1Y=w544-h544-l90-rj',
              durationSeconds: 269,
            ),
          ),
          const SizedBox(height: 12),

          // Test Song 2: Tum Hi Ho
          _buildTestSongCard(
            const SongModel(
              id: 'NUo8CKI34o4',
              title: 'Tum Hi Ho',
              artist: 'Arijit Singh, Mithoon',
              album: 'Aashiqui 2',
              thumbnailUrl: 'https://yt3.googleusercontent.com/3q33amH9hzn1dO8IeAX7TMb1QtEVfvVbqd2eSCaelOXNVmfMjbpDYdqD2HSiXtNP6i5Es7oynkWU2NfOXA=w544-h544-l90-rj',
              durationSeconds: 262,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestSongCard(SongModel song) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            song.thumbnailUrl ?? '',
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: Colors.white54),
          ),
        ),
        title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54)),
        trailing: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF6C5CE7),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
            onPressed: () {
              ref.read(playerControllerProvider.notifier).playSong(song);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderTab(String title, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: const Color(0xFF6C5CE7)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 16, color: Colors.white70)),
        ],
      ),
    );
  }
}
