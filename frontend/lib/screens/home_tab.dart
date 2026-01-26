import 'dart:convert';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/cache_service.dart';
import '../widgets/adaptive_song_card.dart';
import 'song_view_screen.dart';

class HomeTab extends StatefulWidget {
  final Function(int) onChangeTab;
  const HomeTab({super.key, required this.onChangeTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _topSongs = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // 1. Сначала пытаемся загрузить из кэша
    final cachedSongs = CacheService.getTopSongs();
    if (cachedSongs != null && cachedSongs.isNotEmpty) {
      if (mounted) {
        setState(() {
          _topSongs = cachedSongs;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    }

    // 2. Если кэша нет, включаем индикатор загрузки
    if (_topSongs.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final url = '${AppConfig.baseUrl}/top';
      final response = await AppConfig.getWithRetry(url);

      final freshSongs = jsonDecode(utf8.decode(response.bodyBytes));

      await CacheService.saveTopSongs(freshSongs);

      if (mounted) {
        setState(() {
          _topSongs = freshSongs;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        if (_topSongs.isNotEmpty) {
          // Кэш есть - работаем оффлайн
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Работаем оффлайн. Показаны сохраненные данные."),
              duration: Duration(seconds: 3),
            ),
          );
          // Выключаем лоадер, так как запрос завершен (хоть и ошибкой)
          setState(() => _isLoading = false);
        } else {
          // Кэша нет - показываем ошибку
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Не удалось загрузить чарт.\nВозможно, сервер просыпается...";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // ВАЖНО: Кастомный экран загрузки (Первый запуск / Холодный старт)
    if (_isLoading && _topSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_download_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                "Загрузка чартов...",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                "Подключаемся к Ultimate Guitar & MyChords...\nЭто может занять до 30 секунд.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Состояние ошибки (только если данных нет)
    if (_errorMessage != null && _topSongs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text("Попробовать снова"),
              ),
            ],
          ),
        ),
      );
    }

    if (_topSongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.trending_up,
              size: 64,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 16),
            const Text("Популярных песен пока нет"),
            TextButton(onPressed: _loadData, child: const Text("Обновить")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: _topSongs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16, left: 8),
              child: Text(
                "Популярное сейчас",
                style: theme.textTheme.titleLarge,
              ),
            );
          }
          final item = _topSongs[index - 1];

          return AdaptiveSongCard(
            title: item['title'] ?? 'Без названия',
            artist: item['artist'] ?? 'Неизвестен',
            url: item['url'],
            source: item['source_label'],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SongViewScreen(
                    title: item['title'] ?? 'Без названия',
                    artist: item['artist'] ?? 'Неизвестен',
                    url: item['url'],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
