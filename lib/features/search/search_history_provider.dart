import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _key = 'ak_search_history';

  SearchHistoryNotifier() : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw != null) {
        final List<dynamic> decoded = jsonDecode(raw);
        state = decoded.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [SEARCH HISTORY LOAD ERROR] $e');
    }
  }

  Future<void> addQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    final updated = [clean, ...state.where((q) => q.toLowerCase() != clean.toLowerCase())];
    final limited = updated.take(20).toList();
    state = limited;

    try {
      await _storage.write(key: _key, value: jsonEncode(limited));
    } catch (e) {
      debugPrint('⚠️ [SEARCH HISTORY SAVE ERROR] $e');
    }
  }

  Future<void> removeQuery(String query) async {
    final updated = state.where((q) => q != query).toList();
    state = updated;
    try {
      await _storage.write(key: _key, value: jsonEncode(updated));
    } catch (e) {
      debugPrint('⚠️ [SEARCH HISTORY DELETE ERROR] $e');
    }
  }

  Future<void> clearAll() async {
    state = [];
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}

final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});
