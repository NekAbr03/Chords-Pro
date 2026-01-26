import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _key = 'favorites_songs';

  static Future<List<Map<String, dynamic>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];
    return rawList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  static Future<void> toggleFavorite(Map<String, dynamic> song) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];
    final String targetUrl = song['url'];
    final int existingIndex = rawList.indexWhere((e) {
      final map = jsonDecode(e);
      return map['url'] == targetUrl;
    });
    if (existingIndex != -1) {
      rawList.removeAt(existingIndex);
    } else {
      rawList.add(jsonEncode(song));
    }
    await prefs.setStringList(_key, rawList);
  }

  static Future<bool> isFavorite(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_key) ?? [];
    return rawList.any((e) {
      final map = jsonDecode(e);
      return map['url'] == url;
    });
  }
}
