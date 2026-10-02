import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import '../../core/config/app_constants.dart';
import '../../data/models/song_model.dart';

class DownloadItem {
  final SongModel song;
  final String localFilePath;
  final int downloadedAt;

  const DownloadItem({
    required this.song,
    required this.localFilePath,
    required this.downloadedAt,
  });

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    'localFilePath': localFilePath,
    'downloadedAt': downloadedAt,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    song: SongModel.fromSearchJson(Map<String, dynamic>.from(json['song'] as Map)),
    localFilePath: json['localFilePath'] as String,
    downloadedAt: json['downloadedAt'] as int,
  );
}

class DownloadController extends StateNotifier<List<DownloadItem>> {
  final Dio _dio = Dio();
  final Set<String> _activeDownloadingSongIds = {};

  DownloadController() : super([]) {
    _loadDownloadedSongs();
  }

  bool isDownloading(String songId) => _activeDownloadingSongIds.contains(songId);
  bool isDownloaded(String songId) => state.any((d) => d.song.id == songId);

  Future<void> _loadDownloadedSongs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/offline_manifest.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final List<dynamic> list = jsonDecode(raw);
        state = list.map((e) => DownloadItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [LOAD OFFLINE SONGS ERROR] $e');
    }
  }

  Future<bool> downloadSong(SongModel song) async {
    if (isDownloaded(song.id) || isDownloading(song.id)) return false;

    _activeDownloadingSongIds.add(song.id);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${song.id}.mp3';
      final downloadUrl = '${AppConstants.baseUrl}/download/${song.id}?apiKey=${AppConstants.apiKey}';

      debugPrint('📥 [DOWNLOAD START] "${song.title}" -> $savePath');

      await _dio.download(
        downloadUrl,
        savePath,
      );

      final item = DownloadItem(
        song: song,
        localFilePath: savePath,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
      );

      final updated = [...state, item];
      state = updated;

      final manifestFile = File('${dir.path}/offline_manifest.json');
      await manifestFile.writeAsString(jsonEncode(updated.map((e) => e.toJson()).toList()));

      debugPrint('✅ [DOWNLOAD COMPLETE] "${song.title}" saved offline!');
      return true;
    } catch (e) {
      debugPrint('❌ [DOWNLOAD ERROR] $e');
      return false;
    } finally {
      _activeDownloadingSongIds.remove(song.id);
    }
  }

  Future<void> removeDownload(String songId) async {
    final item = state.firstWhere((d) => d.song.id == songId, orElse: () => throw Exception('Not found'));
    final file = File(item.localFilePath);
    if (await file.exists()) await file.delete();

    final updated = state.where((d) => d.song.id != songId).toList();
    state = updated;

    final dir = await getApplicationDocumentsDirectory();
    final manifestFile = File('${dir.path}/offline_manifest.json');
    await manifestFile.writeAsString(jsonEncode(updated.map((e) => e.toJson()).toList()));
  }
}

final downloadControllerProvider = StateNotifierProvider<DownloadController, List<DownloadItem>>((ref) {
  return DownloadController();
});
