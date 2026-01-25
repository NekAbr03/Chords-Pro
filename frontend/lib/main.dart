import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Для определения языка и платформы
import 'dart:ui'; // Для ImageFilter (BackdropFilter)
import 'package:flutter/foundation.dart'; // Для kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// ... (AppConfig, FavoritesService, Models - БЕЗ ИЗМЕНЕНИЙ) ...
// ... (Вставь сюда AppConfig, FavoritesService, SongLine, ChordData, MusicTheory из твоего кода) ...

class AppConfig {
  static const String serverIp = '192.168.0.17';
  static String get baseUrl {
    return 'https://chords-pro.onrender.com';
  }

  /// Выполняет GET запрос с автоматическими повторными попытками
  /// 1-я попытка: сразу
  /// 2-я попытка: через 1 секунду
  /// 3-я попытка: через 2 секунды
  /// Если все попытки провалены, пробрасывает исключение
  static Future<http.Response> getWithRetry(
    String url, {
    int maxAttempts = 3,
  }) async {
    final List<int> delaySeconds = [0, 1, 2];

    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Ожидаем перед попыткой (для 2-й и 3-й попыток)
        if (attempt > 1) {
          await Future.delayed(Duration(seconds: delaySeconds[attempt - 1]));
        }

        final Uri uri = Uri.parse(url);
        final response = await http
            .get(uri)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () =>
                  throw TimeoutException('Timeout при получении $url'),
            );

        // Если статус 200 - успех
        if (response.statusCode == 200) {
          return response;
        }

        // Если статус не 200, выводим ошибку и продолжаем попытки
        debugPrint(
          'getWithRetry попытка $attempt/$maxAttempts: статус ${response.statusCode} для $url',
        );
      } catch (e) {
        // Выводим ошибку при исключении
        debugPrint(
          'getWithRetry попытка $attempt/$maxAttempts: исключение для $url - $e',
        );

        // Если это последняя попытка, пробрасываем исключение
        if (attempt == maxAttempts) {
          rethrow;
        }
      }
    }

    // Этот код не должен быть достигнут, но на случай
    throw Exception(
      'getWithRetry: все $maxAttempts попытки провалены для $url',
    );
  }
}

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

class SongLine {
  final String original;
  final String romaji;
  SongLine({required this.original, required this.romaji});
  factory SongLine.fromJson(Map<String, dynamic> json) {
    return SongLine(
      original: json['original'] ?? '',
      romaji: json['romaji'] ?? '',
    );
  }
}

class ChordData {
  final String name;
  final String positions;
  ChordData(this.name, this.positions);
}

class MusicTheory {
  static const _notes = [
    'C',
    'C#',
    'D',
    'D#',
    'E',
    'F',
    'F#',
    'G',
    'G#',
    'A',
    'A#',
    'B',
  ];
  static const _flatToSharp = {
    'Db': 'C#',
    'Eb': 'D#',
    'Gb': 'F#',
    'Ab': 'G#',
    'Bb': 'A#',
    'Cb': 'B',
    'Fb': 'E',
  };
  static String transposeChord(String chord, int semitones) {
    if (semitones == 0) return chord;
    if (chord.contains('/'))
      return chord
          .split('/')
          .map((part) => transposeChord(part, semitones))
          .join('/');
    final match = RegExp(r'^([A-G][#b]?)(.*)$').firstMatch(chord);
    if (match == null) return chord;
    String root = match.group(1)!;
    String suffix = match.group(2)!;
    String lookupRoot = _flatToSharp[root] ?? root;
    int index = _notes.indexOf(lookupRoot);
    if (index == -1) return chord;
    int newIndex = (index + semitones) % 12;
    if (newIndex < 0) newIndex += 12;
    return _notes[newIndex] + suffix;
  }
}

// ============================================================================
// WIDGET: ADAPTIVE SONG CARD (NEW)
// ============================================================================

class AdaptiveSongCard extends StatelessWidget {
  final String title;
  final String artist;
  final String url;
  final VoidCallback onTap;

  const AdaptiveSongCard({
    super.key,
    required this.title,
    required this.artist,
    required this.url,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // --- 1. ANDROID (Material Design 3 - Без изменений) ---
    if (!kIsWeb && Platform.isAndroid) {
      return Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: _buildContent(theme),
        ),
      );
    }

    // --- 2. IOS NATIVE (UiKitView + Blur) ---
    if (!kIsWeb && Platform.isIOS) {
      return Container(
        height: 80, // Фиксированная высота для iOS карточки
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Нативное стекло
              const UiKitView(viewType: 'liquid-glass-view'),
              // Контент с эффектом нажатия
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Center(child: _buildContent(theme)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // --- 3. WEB (Flutter Liquid Glass Simulation) ---
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.3)
                : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Размытие фона
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withOpacity(0.2)
                      : Colors.white.withOpacity(0.2), // Полупрозрачная заливка
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withOpacity(
                      0.2,
                    ), // Тонкая обводка (Frost)
                    width: 1.0,
                  ),
                ),
              ),
            ),
            // Контент
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(20),
                child: _buildContent(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer.withOpacity(
                0.8,
              ), // Прозрачность для стекла
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.music_note,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  artist,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

// ============================================================================
// 2. MAIN & THEME
// ============================================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );
  runApp(const MusicChordsApp());
}

class MusicChordsApp extends StatelessWidget {
  const MusicChordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    const pastelPurple = Color(0xFFD0BCFF);

    // Цвет фона: Для Android дефолт, для iOS/Web - светло-серый (чтобы стекло работало)
    final bool useGlassBackground = kIsWeb || (!kIsWeb && Platform.isIOS);
    final lightBg = useGlassBackground
        ? const Color(0xFFF2F2F7)
        : const Color(0xFFFDFDFD);
    final darkBg = useGlassBackground
        ? const Color(0xFF000000)
        : const Color(0xFF0F0F0F);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        ColorScheme lightScheme =
            lightDynamic?.copyWith(brightness: Brightness.light) ??
            ColorScheme.fromSeed(
              seedColor: pastelPurple,
              brightness: Brightness.light,
            );
        ColorScheme darkScheme =
            darkDynamic?.copyWith(brightness: Brightness.dark) ??
            ColorScheme.fromSeed(
              seedColor: pastelPurple,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          title: 'Chords Pro',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: lightBg, // АДАПТИВНЫЙ ФОН
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.light().textTheme),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorScheme: darkScheme,
            scaffoldBackgroundColor: darkBg, // АДАПТИВНЫЙ ФОН
            textTheme: GoogleFonts.robotoTextTheme(ThemeData.dark().textTheme),
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: ZoomPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
              },
            ),
          ),
          home: const MainScreen(),
        );
      },
    );
  }
}

// ============================================================================
// 3. HOME TAB (POPULAR SONGS)
// ============================================================================

class HomeTab extends StatefulWidget {
  final Function(int) onChangeTab;
  const HomeTab({super.key, required this.onChangeTab});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<dynamic> _topSongs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTopSongs();
  }

  Future<void> _loadTopSongs() async {
    try {
      final url = '${AppConfig.baseUrl}/top';
      final response = await AppConfig.getWithRetry(url);
      if (mounted) {
        setState(() {
          _topSongs = jsonDecode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) return const Center(child: CircularProgressIndicator());

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
            TextButton(onPressed: _loadTopSongs, child: const Text("Обновить")),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTopSongs,
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

          // ИСПОЛЬЗУЕМ НОВУЮ АДАПТИВНУЮ КАРТОЧКУ
          return AdaptiveSongCard(
            title: item['title'] ?? 'Без названия',
            artist: item['artist'] ?? 'Неизвестен',
            url: item['url'],
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

// ============================================================================
// 4. SEARCH SCREEN
// ============================================================================

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
      final url = '${AppConfig.baseUrl}/search?q=${Uri.encodeComponent(query)}';
      final response = await AppConfig.getWithRetry(url);

      final List<dynamic> results = jsonDecode(utf8.decode(response.bodyBytes));
      setState(() {
        _searchResults = results;
        _nothingFound = results.isEmpty;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _error = "Ошибка подключения.\nПроверьте интернет.";
      });
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

// ... (MainScreen, SongViewScreen БЕЗ ИЗМЕНЕНИЙ ДО SongViewScreenState) ...

// ============================================================================
// 5. MAIN SCREEN
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final ScrollController _homeScrollController = ScrollController();
  final ScrollController _searchScrollController = ScrollController();
  final ScrollController _libraryScrollController = ScrollController();

  Future<List<Map<String, dynamic>>> _loadLibrary() async {
    return await FavoritesService.getFavorites();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      switch (index) {
        case 0:
          if (_homeScrollController.hasClients) {
            _homeScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          break;
        case 1:
          if (_searchScrollController.hasClients) {
            _searchScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          break;
        case 2:
          if (_libraryScrollController.hasClients) {
            _libraryScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          break;
      }
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определение языка системы
    final String locale = kIsWeb ? 'ru_RU' : Platform.localeName;
    final bool isRu = locale.startsWith('ru');
    final String labelHome = isRu ? "Главная" : "Home";
    final String labelSearch = isRu ? "Поиск" : "Search";
    final String labelSaved = isRu ? "Сохраненные" : "Saved";

    Widget buildLibraryList() {
      return FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadLibrary(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final songs = snapshot.data!;
          if (songs.isEmpty)
            return const Center(child: Text("Нет сохраненных песен"));

          return ListView.builder(
            controller: _libraryScrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return AdaptiveSongCard(
                title: song["title"] ?? "Без названия",
                artist: song["artist"] ?? "Неизвестен",
                url: song["url"],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SongViewScreen(
                        title: song["title"] ?? "Без названия",
                        artist: song["artist"] ?? "Неизвестен",
                        url: song["url"],
                      ),
                    ),
                  ).then((_) => setState(() {}));
                },
              );
            },
          );
        },
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        forceMaterialTransparency: true,
        title: Text(
          _selectedIndex == 0
              ? labelHome
              : _selectedIndex == 1
              ? labelSearch
              : labelSaved,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            HomeTab(onChangeTab: _onItemTapped),
            IgnorePointer(
              ignoring: _selectedIndex != 1,
              child: SearchScreen(scrollController: _searchScrollController),
            ),
            IgnorePointer(
              ignoring: _selectedIndex != 2,
              child: buildLibraryList(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        backgroundColor: Theme.of(context).colorScheme.surface,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: labelHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.search_outlined),
            selectedIcon: const Icon(Icons.search),
            label: labelSearch,
          ),
          NavigationDestination(
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: labelSaved,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 6. SONG VIEW SCREEN (COLLAPSIBLE + GRAPHIC CHORDS)
// ============================================================================

class SongViewScreen extends StatefulWidget {
  final String title;
  final String artist;
  final String? url;

  const SongViewScreen({
    super.key,
    required this.title,
    required this.artist,
    this.url,
  });

  @override
  State<SongViewScreen> createState() => _SongViewScreenState();
}

class _SongViewScreenState extends State<SongViewScreen> {
  // STATE
  List<String> _rawUniqueChords = [];
  int _transposeLevel = 0;

  // PANEL STATE
  final ScrollController _chordScrollController = ScrollController();
  bool _isPanelExpanded = false;
  static const double _panelCollapsedSize = 56.0;
  static const double _panelMarginCollapsed = 16.0;
  static const double _panelExpandedHeight = 200.0;

  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    if (widget.url != null) {
      final isFav = await FavoritesService.isFavorite(widget.url!);
      if (mounted) setState(() => _isFavorite = isFav);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.url == null) return;
    await FavoritesService.toggleFavorite({
      'title': widget.title,
      'artist': widget.artist,
      'url': widget.url,
    });
    _checkFavorite();
  }

  // --- ФИКС БАГА СО СКРОЛЛОМ ---
  void _scrollToChord(String rawChordName) {
    if (_rawUniqueChords.isEmpty) return;
    final index = _rawUniqueChords.indexOf(rawChordName);

    if (index != -1) {
      const itemWidth = 96.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset =
          (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      // Проверяем наличие клиентов. Если панель только открывается, клиентов может не быть.
      if (_chordScrollController.hasClients) {
        final maxScroll = _chordScrollController.position.maxScrollExtent;
        _chordScrollController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Если клиентов нет (панель в процессе открытия), пробуем еще раз чуть позже
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted && _chordScrollController.hasClients) {
            final maxScroll = _chordScrollController.position.maxScrollExtent;
            _chordScrollController.animateTo(
              targetOffset.clamp(0.0, maxScroll),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      }
    }
  }

  String _getMockPositions(String chordName) {
    final hash = chordName.hashCode;
    if (chordName.startsWith('C')) return 'x32010';
    if (chordName.startsWith('A')) return 'x02210';
    if (chordName.startsWith('G')) return '320003';
    if (chordName.startsWith('D')) return 'xx0232';
    if (chordName.startsWith('E')) return '022100';
    if (chordName.startsWith('F')) return '133211';
    return 'x${hash % 5}${hash % 4}0${hash % 3}${hash % 2}';
  }

  void _onPanelDragUpdate(DragUpdateDetails details) {
    if (_isPanelExpanded && details.delta.dy > 2) {
      setState(() => _isPanelExpanded = false);
    }
  }

  void _togglePanel() {
    setState(() => _isPanelExpanded = !_isPanelExpanded);
  }

  void _onChordTapInternal(String rawChordName) {
    // 1. Открываем панель
    setState(() => _isPanelExpanded = true);

    // 2. Ждем завершения анимации открытия (300мс) + небольшой буфер
    // Важно: AnimatedContainer занимает 300мс.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _scrollToChord(rawChordName);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final adaptiveHeight = (screenHeight * 0.25).clamp(140.0, 180.0);

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            Text(widget.artist, style: theme.textTheme.bodySmall),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite
                  ? Colors.redAccent
                  : theme.colorScheme.onSurface,
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            bottom: _isPanelExpanded ? _panelExpandedHeight : 0,
            child: LyricsRenderArea(
              url: widget.url,
              transposeLevel: _transposeLevel,
              bottomPadding: _isPanelExpanded ? _panelExpandedHeight + 20 : 0,
              onTransposeChange: (newLevel) =>
                  setState(() => _transposeLevel = newLevel),
              onChordsLoaded: (chords) {
                if (!listEquals(_rawUniqueChords, chords)) {
                  setState(() => _rawUniqueChords = chords);
                }
              },
              onChordTap: _onChordTapInternal, // Используем исправленный метод
            ),
          ),
          Align(
            alignment: _isPanelExpanded
                ? Alignment.bottomCenter
                : Alignment.bottomRight,
            child: GestureDetector(
              onVerticalDragUpdate: _onPanelDragUpdate,
              onTap: _isPanelExpanded ? null : _togglePanel,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: _isPanelExpanded ? screenWidth : _panelCollapsedSize,
                height: _isPanelExpanded ? adaptiveHeight : _panelCollapsedSize,
                margin: EdgeInsets.only(
                  right: _isPanelExpanded ? 0 : _panelMarginCollapsed,
                  bottom: _isPanelExpanded ? 0 : _panelMarginCollapsed,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: _isPanelExpanded
                      ? const BorderRadius.vertical(top: Radius.circular(24))
                      : BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // ВАЖНО: Используем Offstage вместо Visibility для сохранения состояния скролла
                    // и чтобы ListView был "жив" даже когда невидим (но не отрисовывался)
                    Offstage(
                      offstage: !_isPanelExpanded,
                      child: _buildExpandedPanel(theme),
                    ),
                    Visibility(
                      visible: !_isPanelExpanded,
                      child: _buildCollapsedButton(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedButton() {
    return Center(
      child: Icon(
        Icons.music_note_outlined,
        size: 28,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }

  Widget _buildExpandedPanel(ThemeData theme) {
    return Column(
      children: [
        Container(
          height: 24,
          alignment: Alignment.center,
          child: Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Expanded(
          child: _rawUniqueChords.isEmpty
              ? Center(
                  child: Text('Загрузка...', style: theme.textTheme.bodyMedium),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: ListView.separated(
                    controller: _chordScrollController,
                    scrollDirection: Axis.horizontal,
                    itemCount: _rawUniqueChords.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final rawName = _rawUniqueChords[index];
                      final displayName = MusicTheory.transposeChord(
                        rawName,
                        _transposeLevel,
                      );
                      final positions = _getMockPositions(displayName);
                      return GestureDetector(
                        onTap: () => _scrollToChord(rawName),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.08)
                                : Colors.black.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: GuitarChordWidget(
                            chord: ChordData(displayName, positions),
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ============================================================================
// 7. LYRICS AREA
// ============================================================================

class LyricsRenderArea extends StatefulWidget {
  final String? url;
  final int transposeLevel;
  final double bottomPadding;
  final Function(int)? onTransposeChange;
  final Function(List<String>)? onChordsLoaded;
  final Function(String)? onChordTap;

  const LyricsRenderArea({
    super.key,
    this.url,
    required this.transposeLevel,
    required this.bottomPadding,
    this.onTransposeChange,
    this.onChordsLoaded,
    this.onChordTap,
  });

  @override
  State<LyricsRenderArea> createState() => _LyricsRenderAreaState();
}

class _LyricsRenderAreaState extends State<LyricsRenderArea> {
  bool _showRomaji = false;
  final bool _showChords = true;
  List<SongLine> _parsedLines = [];
  bool _isLoading = true;
  bool _isError = false;
  bool _isSlowLoading = false;
  String? _errorMessage;
  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (widget.url == null) {
      setState(() {
        _isLoading = false;
        _isError = true;
        _errorMessage = 'Песня не найдена';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _isError = false;
      _isSlowLoading = false;
      _errorMessage = null;
    });

    // Запускаем таймер на 3 секунды для "умной" индикации
    _loadingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isLoading) {
        setState(() => _isSlowLoading = true);
      }
    });

    try {
      final url = '${AppConfig.baseUrl}/parse?url=${widget.url!}';
      final response = await AppConfig.getWithRetry(url).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Сервер не отвечает'),
      );

      _loadingTimer?.cancel();

      final Map<String, dynamic> decodedMap = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      final List<dynamic> linesList = decodedMap['lines'];

      final List<String> orderedChords = [];
      final Set<String> seenChords = {};
      final RegExp chordRegex = RegExp(r'\{([^}]+)\}');

      for (var lineJson in linesList) {
        String original = lineJson['original'] ?? '';
        final matches = chordRegex.allMatches(original);
        for (var match in matches) {
          final chord = match.group(1);
          if (chord != null && !seenChords.contains(chord)) {
            seenChords.add(chord);
            orderedChords.add(chord);
          }
        }
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChordsLoaded?.call(orderedChords);
      });

      if (mounted) {
        setState(() {
          _parsedLines = linesList
              .map((json) => SongLine.fromJson(json))
              .toList();
          _isLoading = false;
          _isSlowLoading = false;
        });
      }
    } on SocketException catch (_) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Нет подключения к интернету';
          _isSlowLoading = false;
        });
      }
    } on TimeoutException catch (_) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Сервер не отвечает';
          _isSlowLoading = false;
        });
      }
    } catch (e) {
      _loadingTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = true;
          _errorMessage = 'Ошибка загрузки';
          _isSlowLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Обработка загрузки с "умной" индикацией
    if (_isLoading) {
      if (_isSlowLoading) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Сервер просыпается...',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Это может занять до 50 секунд (первый запуск)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Обработка ошибок с подробными сообщениями
    if (_isError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.broken_image_outlined,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Ошибка загрузки',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text('Повторить')),
          ],
        ),
      );
    }

    // 2. Данные точно загружены. Теперь определяем hasRomaji.
    // Переменная объявляется здесь, поэтому она видна во всем коде ниже.
    final bool hasRomaji = _parsedLines.any((line) {
      final String r = line.romaji.trim();
      final String o = line.original.trim();
      // Кнопка появится только если romaji не пустое И оно отличается от оригинала
      return r.isNotEmpty && r != o;
    });

    final contentBackgroundColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHigh
        : theme.colorScheme.surfaceContainerLow;

    return Container(
      color: contentBackgroundColor,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(16, 16, 16, widget.bottomPadding),
        itemCount: _parsedLines.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          // HEADER (Кнопки управления)
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  // Блок транспонирования
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        // ignore: deprecated_member_use
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => widget.onTransposeChange?.call(
                            widget.transposeLevel - 1,
                          ),
                          child: const Icon(Icons.remove, size: 20),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            widget.transposeLevel > 0
                                ? "+${widget.transposeLevel}"
                                : "${widget.transposeLevel}",
                            style: GoogleFonts.roboto(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () => widget.onTransposeChange?.call(
                            widget.transposeLevel + 1,
                          ),
                          child: const Icon(Icons.add, size: 20),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ФУНКЦИЯ ROMANIZED ОТКЛЮЧЕНА
                  // Функция полностью реализована, однако отключена за ненадобностью
                  // в связи с временным отсутствием доступа к базам азиатских песен.
                  // Переключатель и логика остаются в коде для будущего использования.
                  /*
                  // ЛОГИКА СКРЫТИЯ ROMAJI
                  // Используем hasRomaji, который мы объявили выше
                  if (hasRomaji) ...[
                    Text("Romaji", style: theme.textTheme.labelMedium),
                    Switch(
                      value: _showRomaji,
                      onChanged: (val) => setState(() => _showRomaji = val),
                    ),
                  ],
                  */
                ],
              ),
            );
          }

          // СТРОКИ ПЕСНИ
          final lineData = _parsedLines[index - 1];
          // Если романизации нет в принципе, всегда показываем оригинал, даже если переключатель заглючил
          final textToRender = (_showRomaji && hasRomaji)
              ? lineData.romaji
              : lineData.original;

          return ChordLyricsLine(
            line: textToRender,
            showChords: _showChords,
            transposeLevel: widget.transposeLevel,
            onChordTap: (rawChord) => widget.onChordTap?.call(rawChord),
          );
        },
      ),
    );
  }
}

class ChordLyricsLine extends StatelessWidget {
  final String line;
  final bool showChords;
  final int transposeLevel;
  final Function(String) onChordTap;

  const ChordLyricsLine({
    super.key,
    required this.line,
    required this.showChords,
    this.transposeLevel = 0,
    required this.onChordTap,
  });

  @override
  Widget build(BuildContext context) {
    final segments = _parseLine(context, line);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      runSpacing: 6.0,
      children: segments,
    );
  }

  List<Widget> _parseLine(BuildContext context, String rawLine) {
    List<Widget> widgets = [];
    List<String> parts = rawLine.split('{');
    if (parts[0].isNotEmpty) widgets.add(_buildText(context, parts[0]));

    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      final splitIndex = part.indexOf('}');
      if (splitIndex != -1) {
        final rawChord = part.substring(0, splitIndex);
        final lyricText = part.substring(splitIndex + 1);
        final displayChord = MusicTheory.transposeChord(
          rawChord,
          transposeLevel,
        );
        widgets.add(
          _buildSegment(
            context,
            displayChord,
            lyricText,
            rawChordForTap: rawChord,
          ),
        );
      } else {
        widgets.add(_buildText(context, part));
      }
    }
    return widgets;
  }

  Widget _buildText(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: GoogleFonts.roboto(
        fontSize: 16,
        height: 1.5,
        color: theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildSegment(
    BuildContext context,
    String? displayChord,
    String lyric, {
    String? rawChordForTap,
  }) {
    final theme = Theme.of(context);
    if (!showChords) return _buildText(context, lyric);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (displayChord != null)
          InkWell(
            onTap: () => onChordTap(rawChordForTap ?? displayChord),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.only(bottom: 2, right: 4),
              child: Text(
                displayChord,
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 0),
        Text(
          lyric,
          style: GoogleFonts.roboto(
            fontSize: 16,
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 8. GRAPHIC CHORD RENDERER
// ============================================================================

class GuitarChordWidget extends StatelessWidget {
  final ChordData chord;
  final Color color;
  const GuitarChordWidget({
    super.key,
    required this.chord,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 65,
            child: CustomPaint(
              painter: _ChordPainter(positions: chord.positions, color: color),
            ),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              chord.name,
              style: GoogleFonts.roboto(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChordPainter extends CustomPainter {
  final String positions;
  final Color color;
  _ChordPainter({required this.positions, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    List<int?> frets = [];
    for (int i = 0; i < positions.length; i++) {
      if (i >= 6) break;
      final char = positions[i];
      if (char == 'x' || char == 'X') {
        frets.add(-1);
      } else {
        frets.add(int.tryParse(char) ?? 0);
      }
    }

    int minFret = 99;
    int maxFret = 0;
    for (var f in frets) {
      if (f != null && f > 0) {
        if (f < minFret) minFret = f;
        if (f > maxFret) maxFret = f;
      }
    }
    if (minFret == 99) minFret = 1;

    int baseFret = (maxFret <= 4) ? 1 : minFret;

    const double topMargin = 12.0;
    const double bottomMargin = 2.0;
    const double leftMargin = 4.0;
    const double rightMargin = 4.0;

    final double gridWidth = size.width - leftMargin - rightMargin;
    final double gridHeight = size.height - topMargin - bottomMargin;

    final double stringGap = gridWidth / 5;
    final double fretGap = gridHeight / 4;

    for (int i = 0; i < 6; i++) {
      double x = leftMargin + i * stringGap;
      canvas.drawLine(
        Offset(x, topMargin),
        Offset(x, size.height - bottomMargin),
        paint,
      );
    }

    for (int i = 0; i <= 4; i++) {
      double y = topMargin + i * fretGap;
      if (i == 0 && baseFret == 1) {
        paint.strokeWidth = 3.0;
        canvas.drawLine(
          Offset(leftMargin, y),
          Offset(leftMargin + gridWidth, y),
          paint,
        );
        paint.strokeWidth = 1.2;
      } else {
        canvas.drawLine(
          Offset(leftMargin, y),
          Offset(leftMargin + gridWidth, y),
          paint,
        );
      }
    }

    if (baseFret > 1) {
      _drawText(
        canvas,
        "${baseFret}fr",
        Offset(0, topMargin + fretGap / 2),
        8,
        color,
      );
    }

    for (int i = 0; i < frets.length; i++) {
      final fretVal = frets[i];
      final double x = leftMargin + i * stringGap;

      if (fretVal == -1) {
        _drawText(canvas, "x", Offset(x, topMargin - 8), 10, color);
      } else if (fretVal == 0) {
        _drawStrokeCircle(canvas, Offset(x, topMargin - 5), 3, color);
      } else if (fretVal != null) {
        int relFret = fretVal - baseFret;
        if (relFret >= 0 && relFret < 5) {
          double y = topMargin + relFret * fretGap + fretGap / 2;
          canvas.drawCircle(Offset(x, y), stringGap * 0.35, fillPaint);
        }
      }
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.bold,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawStrokeCircle(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
