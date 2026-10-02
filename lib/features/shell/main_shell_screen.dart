import 'song_action_sheet.dart';
import '../../core/network/network_status_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../search/search_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_modal.dart';
import 'mini_player_bar.dart';
import '../../data/models/song_model.dart';
import '../../data/services/music_api_service.dart';
import '../../data/repositories/user_repository.dart';
import '../../player/player_controller.dart';

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentIndex = 0;
  bool _isLoadingHome = false;

  // Shelves / Lists
  List<SongModel> _suggestedSongs = [];
  List<SongModel> _punjabiSongs = [];
  List<SongModel> _bollywoodSongs = [];
  List<SongModel> _lofiSongs = [];
  List<SongModel> _activeMoodSongs = [];

  final List<String> _moodTags = [
    'All', 
    'Punjabi',
    'Romantic',
    'Lo-Fi',
    'Bollywood',
    'Workout',
    'Party',
  ];

  String _selectedMood = 'All';

  @override
  void initState() {
    super.initState();
    _loadAllHomeData();
  }

  Future<void> _loadAllHomeData() async {
    if (_suggestedSongs.isEmpty) {
      setState(() => _isLoadingHome = true);
    }
    final api = ref.read(musicApiServiceProvider);

    try {
      // 1. Instantly fetch & display the Home Feed (Suggested For You in <1s)
      final feed = await api.getHomeFeed(limit: 20);
      if (mounted) {
        setState(() {
          _suggestedSongs = feed;
          _isLoadingHome = false;
        });
      }

      // 2. Fetch Punjabi, Bollywood & Lo-Fi shelves in background progressively
      api.search('Top Punjabi Songs 2026 Sidhu Diljit Karan Aujla', type: 'song').then((punjabi) {
        if (mounted) setState(() => _punjabiSongs = punjabi);
      }).catchError((_) {});

      api.search('Bollywood Romantic Hits 2026', type: 'song').then((bollywood) {
        if (mounted) setState(() => _bollywoodSongs = bollywood);
      }).catchError((_) {});

      api.search('Hindi Lo-Fi Chill Beats Midnight', type: 'song').then((lofi) {
        if (mounted) setState(() => _lofiSongs = lofi);
      }).catchError((_) {});
    } catch (_) {
      if (mounted) setState(() => _isLoadingHome = false);
    }
  }

  Future<void> _loadMoodSongs(String mood) async {
    setState(() => _isLoadingHome = true);
    final api = ref.read(musicApiServiceProvider);
    String query = mood;
    switch (mood) {
      case 'Suggested':
        query = 'Trending Hits 2026';
        break;
      case 'Romantic':
        query = 'Bollywood Romantic Hits 2026';
        break;
      case 'Punjabi':
        query = 'Top Punjabi Songs 2026 Sidhu Diljit Karan Aujla';
        break;
      case 'Lo-Fi':
        query = 'Hindi Lo-Fi Chill Beats Midnight';
        break;
      case 'Bollywood':
        query = 'Best Bollywood Songs 2026';
        break;
      case 'Workout':
        query = 'High Energy Workout Punjabi Hindi';
        break;
      case 'Party':
        query = 'Bollywood Dance Party Hits';
        break;
    }

    try {
      final songs = await api.search(query, type: 'song');
      if (mounted) {
        setState(() {
          _activeMoodSongs = songs;
          _isLoadingHome = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHome = false);
    }
  }

  void _onMoodSelected(String mood) {
    setState(() => _selectedMood = mood);
    if (mood == 'All') {
      if (_suggestedSongs.isEmpty) _loadAllHomeData();
    } else {
      _loadMoodSongs(mood);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 1. Live Home Feed with Vertical Lists
          _buildLiveHomeTab(),
          // 2. Live Search Screen with History
          const SearchScreen(),
          // 3. Real Library Screen (Favorites, History, Downloads)
          const LibraryScreen(),
          // 4. Settings Screen with Auth & Account
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          OfflineBanner(
            onReconnected: () {
              if (_selectedMood == 'All') {
                _loadAllHomeData();
              } else {
                _loadMoodSongs(_selectedMood);
              }
            },
          ),
          const MiniPlayerBar(),
          BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: const Color(0xFF121212),
            selectedItemColor: const Color(0xFF6C5CE7),
            unselectedItemColor: Colors.white54,
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
              BottomNavigationBarItem(icon: Icon(Icons.library_music), label: 'Library'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveHomeTab() {
    final authState = ref.watch(authControllerProvider);
    final userName = authState.user?.name ?? 'Guest Listener';
    final isGuest = authState.isGuest;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => _selectedMood == 'All' ? _loadAllHomeData() : _loadMoodSongs(_selectedMood),
        color: const Color(0xFF6C5CE7),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Top Header: Greeting & Account Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, $userName 👋', style: const TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 2),
                        const Text('AK Music', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.search_rounded, size: 26, color: Colors.white70),
                      onPressed: () => setState(() => _currentIndex = 1),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (isGuest) {
                          AuthModal.show(context);
                        } else {
                          setState(() => _currentIndex = 3);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isGuest ? const Color(0xFF2C2C2C) : const Color(0xFF6C5CE7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isGuest ? Icons.person_outline_rounded : Icons.person_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Horizontal Mood Tags Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _moodTags.map((tag) {
                  final isSelected = _selectedMood == tag;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(tag),
                      selected: isSelected,
                      selectedColor: const Color(0xFF6C5CE7),
                      backgroundColor: const Color(0xFF1E1E1E),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) => _onMoodSelected(tag),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (_isLoadingHome)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
                ),
              )
            else if (_selectedMood != 'All')
              // Display filtered mood list
              ...[
                if (_activeMoodSongs.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No tracks found. Pull down to refresh.', style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  ..._activeMoodSongs.map((song) => _buildSongCard(song, _activeMoodSongs)),
              ]
            else
              // Vertical Categorized Lists
              ...[
                // Section 1: Suggested For You (Top List)
                if (_suggestedSongs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Suggested For You', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ..._suggestedSongs.map((song) => _buildSongCard(song, _suggestedSongs)),
                  const SizedBox(height: 16),
                ],

                // Section 2: Punjabi Hits
                if (_punjabiSongs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Trending Punjabi Hits', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ..._punjabiSongs.map((song) => _buildSongCard(song, _punjabiSongs)),
                  const SizedBox(height: 16),
                ],

                // Section 3: Bollywood Romance
                if (_bollywoodSongs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Bollywood Romance', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ..._bollywoodSongs.map((song) => _buildSongCard(song, _bollywoodSongs)),
                  const SizedBox(height: 16),
                ],

                // Section 4: Lo-Fi Chill
                if (_lofiSongs.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Midnight Lo-Fi & Chill', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  ..._lofiSongs.map((song) => _buildSongCard(song, _lofiSongs)),
                ],
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildSongCard(SongModel song, List<SongModel> playlist) {
    final isFav = ref.watch(favoritesProvider).any((s) => s.id == song.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () {
            ref.read(playerControllerProvider.notifier).playSong(song, playlist: playlist);
          },
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (song.thumbnailUrl ?? song.highResThumbnail) != null
                ? CachedNetworkImage(
                    imageUrl: (song.thumbnailUrl ?? song.highResThumbnail)!,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    placeholder: (_, __) => Container(
                      width: 50,
                      height: 50,
                      color: const Color(0xFF22222E),
                      child: const Center(
                        child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 22),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 50,
                      height: 50,
                      color: const Color(0xFF22222E),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
                    color: const Color(0xFF22222E),
                    padding: const EdgeInsets.all(6),
                    child: Image.asset('assets/logo.png', fit: BoxFit.contain),
                  ),
          ),
          title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white54, size: 20),
                tooltip: 'Options',
                onPressed: () => SongActionSheet.show(context, song),
              ),
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: isFav ? Colors.redAccent : Colors.white38,
                  size: 22,
                ),
                onPressed: () {
                  ref.read(favoritesProvider.notifier).toggleFavorite(song);
                },
              ),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF6C5CE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
