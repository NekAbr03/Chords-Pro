import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../services/cache_service.dart'; // Не забудь импорт
import '../widgets/adaptive_song_card.dart';
import 'song_view_screen.dart';

class SearchScreen extends StatefulWidget {
  final ScrollController scrollController;
  const SearchScreen({super.key, required this.scrollController});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _searchResults = [];
  List<String> _history = [];
  bool _isSearching = false;
  String? _error;
  bool _nothingFound = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.remove(query);
      _history.insert(0, query);
      if (_history.length > 10) _history = _history.sublist(0, 10);
    });
    await prefs.setStringList('search_history', _history);
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _history.remove(query);
    });
    await prefs.setStringList('search_history', _history);
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) return;
    _addToHistory(query);
    _searchController.text = query;
    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSearching = true;
      _error = null;
      _nothingFound = false;
      _searchResults = [];
    });

    try {
      // 1. Пробуем поиск через API
      final url = '${AppConfig.baseUrl}/search?q=${Uri.encodeComponent(query)}';
      final response = await AppConfig.getWithRetry(url);

      final List<dynamic> results = jsonDecode(utf8.decode(response.bodyBytes));

      if (mounted) {
        setState(() {
          _searchResults = results;
          _nothingFound = results.isEmpty;
          _isSearching = false;
        });
      }
    } catch (e) {
      // 2. Если API недоступен, ищем локально
      if (mounted) {
        final localResults = CacheService.searchLocalSongs(query);

        if (localResults.isNotEmpty) {
          setState(() {
            _searchResults = localResults;
            _nothingFound = false;
            _isSearching = false; // Выключаем лоадер
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Поиск без интернета. Найдено в кэше."),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          // Если и локально пусто, показываем ошибку
          setState(() {
            _isSearching = false;
            _error = "Ошибка подключения.\nПроверьте интернет.";
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget buildBody() {
      if (_isSearching) return const Center(child: CircularProgressIndicator());
      if (_error != null)
        return Center(child: Text(_error!, textAlign: TextAlign.center));
      if (_nothingFound) return const Center(child: Text("Ничего не найдено"));

      if (_searchResults.isNotEmpty) {
        return ListView.builder(
          controller: widget.scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _searchResults.length,
          itemBuilder: (context, index) {
            final item = _searchResults[index];
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
                ).then((_) => setState(() {}));
              },
            );
          },
        );
      }

      if (_history.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 16, 8),
              child: Text(
                "Недавние",
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _history.length,
                itemBuilder: (context, index) {
                  final historyItem = _history[index];
                  return ListTile(
                    leading: const Icon(Icons.history, size: 20),
                    title: Text(historyItem),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _removeFromHistory(historyItem),
                    ),
                    onTap: () => _performSearch(historyItem),
                  );
                },
              ),
            ),
          ],
        );
      }
      return const Center(child: Text("Введите запрос для поиска"));
    }

    final bool canPop =
        _searchResults.isEmpty && _searchController.text.isEmpty;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        setState(() {
          _searchController.clear();
          _searchResults = [];
          _error = null;
          _nothingFound = false;
        });
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Поиск песен...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                        _error = null;
                        _nothingFound = false;
                      });
                      FocusManager.instance.primaryFocus?.unfocus();
                    },
                  ),
              ],
              onSubmitted: _performSearch,
              onChanged: (text) {
                if (text.isEmpty) {
                  setState(() {
                    _searchResults = [];
                    _error = null;
                    _nothingFound = false;
                  });
                }
              },
              elevation: WidgetStateProperty.all(0),
              backgroundColor: WidgetStateProperty.all(
                theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          ),
          Expanded(child: buildBody()),
        ],
      ),
    );
  }
}
