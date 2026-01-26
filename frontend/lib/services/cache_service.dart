import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheService {
  static const String _boxName = 'app_cache';
  static const String _keyTopSongs = 'top_songs';

  /// Инициализация Hive и открытие бокса
  static Future<void> initHive() async {
    await Hive.initFlutter();
    await Hive.openBox(_boxName);
  }

  /// Получаем доступ к открытому боксу
  static Box get _box => Hive.box(_boxName);

  // ==========================================================================
  // TOP SONGS
  // ==========================================================================

  static Future<void> saveTopSongs(List<dynamic> songs) async {
    await _box.put(_keyTopSongs, jsonEncode(songs));
  }

  static List<dynamic>? getTopSongs() {
    final String? data = _box.get(_keyTopSongs);
    if (data == null) return null;
    try {
      return jsonDecode(data);
    } catch (e) {
      return null;
    }
  }

  // ==========================================================================
  // FULL SONG DATA
  // ==========================================================================

  static Future<void> saveSongData(
    String url,
    Map<String, dynamic> data,
  ) async {
    await _box.put(url, jsonEncode(data));
  }

  static Map<String, dynamic>? getSongData(String url) {
    final String? data = _box.get(url);
    if (data == null) return null;
    try {
      return jsonDecode(data) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  static bool hasSongData(String url) {
    return _box.containsKey(url);
  }

  // ==========================================================================
  // SMART OFFLINE SEARCH
  // ==========================================================================

  /// Поиск по локальной базе (заголовки, артисты и ТЕКСТ песен)
  static List<Map<String, dynamic>> searchLocalSongs(String query) {
    final String q = query.toLowerCase().trim();
    if (q.isEmpty) return [];

    final List<Map<String, dynamic>> results = [];

    // Перебираем все значения в боксе
    for (var value in _box.values) {
      // У нас все хранится как JSON String
      if (value is! String) continue;

      try {
        final dynamic decoded = jsonDecode(value);

        // Нас интересуют только песни (Map), пропускаем списки (например top_songs)
        if (decoded is! Map<String, dynamic>) continue;

        // Проверяем обязательные поля, чтобы убедиться, что это песня
        if (!decoded.containsKey('title') || !decoded.containsKey('url')) {
          continue;
        }

        final String title = (decoded['title'] ?? '').toString().toLowerCase();
        final String artist = (decoded['artist'] ?? '')
            .toString()
            .toLowerCase();

        bool isMatch = false;

        // 1. Поиск по заголовку и артисту
        if (title.contains(q) || artist.contains(q)) {
          isMatch = true;
        }

        // 2. Поиск по тексту песни (Deep Search)
        if (!isMatch && decoded['lines'] is List) {
          final List lines = decoded['lines'];
          for (var line in lines) {
            final String original = (line['original'] ?? '')
                .toString()
                .toLowerCase();
            final String romaji = (line['romaji'] ?? '')
                .toString()
                .toLowerCase();

            if (original.contains(q) || romaji.contains(q)) {
              isMatch = true;
              break; // Нашли совпадение в строке, дальше перебирать эту песню нет смысла
            }
          }
        }

        if (isMatch) {
          // Копируем карту, чтобы не мутировать исходник (хотя jsonDecode создает новую)
          final Map<String, dynamic> hit = Map<String, dynamic>.from(decoded);
          // Добавляем метку, что это из кэша
          hit['source_label'] = 'Offline Cache';
          results.add(hit);
        }
      } catch (e) {
        // Игнорируем битые JSON
        continue;
      }
    }

    return results;
  }
}
