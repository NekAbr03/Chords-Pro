import 'dart:convert';
import 'dart:io'; // Для определения языка
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// ============================================================================
// 0. CONFIG & SERVICES
// ============================================================================

class AppConfig {
  static const String serverIp = '192.168.0.17'; // Твой IP

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:8000';
    return 'http://$serverIp:8000';
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

// ============================================================================
// 1. MODELS & UTILS
// ============================================================================

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
    if (chord.contains('/')) {
      return chord
          .split('/')
          .map((part) => transposeChord(part, semitones))
          .join('/');
    }
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
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: lightScheme,
            scaffoldBackgroundColor: const Color(0xFFFDFDFD),
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
            scaffoldBackgroundColor: const Color(0xFF0F0F0F),
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
      final Uri uri = Uri.parse('${AppConfig.baseUrl}/top');
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _topSongs = jsonDecode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Error');
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
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerLow,
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
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
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.whatshot,
                        color: theme.colorScheme.onSecondaryContainer,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] ?? 'Без названия',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item['artist'] ?? 'Неизвестен',
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
              ),
            ),
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
      final Uri uri = Uri.parse(
        '${AppConfig.baseUrl}/search?q=${Uri.encodeComponent(query)}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> results = jsonDecode(
          utf8.decode(response.bodyBytes),
        );
        setState(() {
          _searchResults = results;
          _nothingFound = results.isEmpty;
          _isSearching = false;
        });
      } else {
        throw Exception('Error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
        _error = "Ошибка подключения.\nПроверьте интернет.";
      });
    }
  }

  Color _getSourceColor(String label, ColorScheme scheme) {
    if (label == 'UG') return Colors.amber;
    if (label == 'MC') return Colors.blueAccent;
    return scheme.primary;
  }

  String _getSourceLabel(dynamic item) {
    if (item['source_label'] != null) return item['source_label'];
    final url = item['url'] as String? ?? '';
    if (url.contains('ultimate-guitar')) return 'UG';
    if (url.contains('mychords')) return 'MC';
    return 'WEB';
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
            final sourceLabel = _getSourceLabel(item);

            return FutureBuilder<bool>(
              future: FavoritesService.isFavorite(item['url']),
              builder: (context, snapshot) {
                final isFav = snapshot.data ?? false;
                return Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
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
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.music_note,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['title'] ?? 'Без названия',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['artist'] ?? 'Неизвестен',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isFav)
                            Icon(
                              Icons.favorite,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getSourceColor(
                                sourceLabel,
                                theme.colorScheme,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sourceLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _getSourceColor(
                                  sourceLabel,
                                  theme.colorScheme,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
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
                if (text.isEmpty)
                  setState(() {
                    _searchResults = [];
                    _error = null;
                    _nothingFound = false;
                  });
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

// ============================================================================
// 5. MAIN SCREEN
// ============================================================================

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 1;
  final PageController _pageController = PageController(initialPage: 1);

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
          if (_homeScrollController.hasClients)
            _homeScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          break;
        case 1:
          if (_searchScrollController.hasClients)
            _searchScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          break;
        case 2:
          if (_libraryScrollController.hasClients)
            _libraryScrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          break;
      }
    } else {
      setState(() => _selectedIndex = index);
      // Плавная анимация
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300), // Длительность 0.3 сек
        curve: Curves.easeInOut, // Плавное ускорение и замедление
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Определение языка системы
    final String locale = Platform.localeName;
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
              return Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
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
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.favorite,
                            color: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song["title"] ?? "",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                song["artist"] ?? "",
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
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
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          HomeTab(onChangeTab: _onItemTapped),
          SearchScreen(scrollController: _searchScrollController),
          buildLibraryList(),
        ],
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
  bool _isPanelExpanded = true;
  double _panelHeight = 140.0;
  final double _maxPanelHeight = 140.0;
  final double _minPanelHeight = 0.0;

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

  void _scrollToChord(String rawChordName) {
    if (!_isPanelExpanded) {
      setState(() {
        _isPanelExpanded = true;
        _panelHeight = _maxPanelHeight;
      });
    }

    if (_rawUniqueChords.isEmpty) return;
    final index = _rawUniqueChords.indexOf(rawChordName);

    if (index != -1) {
      const itemWidth = 96.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset =
          (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chordScrollController.hasClients) {
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

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _panelHeight -= details.delta.dy;
      _panelHeight = _panelHeight.clamp(_minPanelHeight, _maxPanelHeight);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_panelHeight > _maxPanelHeight / 2) {
      setState(() {
        _panelHeight = _maxPanelHeight;
        _isPanelExpanded = true;
      });
    } else {
      setState(() {
        _panelHeight = _minPanelHeight;
        _isPanelExpanded = false;
      });
    }
  }

  void _togglePanel() {
    setState(() {
      _isPanelExpanded = !_isPanelExpanded;
      _panelHeight = _isPanelExpanded ? _maxPanelHeight : _minPanelHeight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double handleHeight = 24.0;
    final double textBottomPadding = _panelHeight + handleHeight + 20;

    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        // Удаляем ведущую иконку, чтобы системный жест назад работал корректно
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

      body: Column(
        children: [
          Expanded(
            child: LyricsRenderArea(
              url: widget.url,
              transposeLevel: _transposeLevel,
              bottomPadding: textBottomPadding,
              onTransposeChange: (newLevel) =>
                  setState(() => _transposeLevel = newLevel),
              onChordsLoaded: (chords) {
                if (!listEquals(_rawUniqueChords, chords)) {
                  setState(() => _rawUniqueChords = chords);
                }
              },
              onChordTap: _scrollToChord,
            ),
          ),

          Divider(height: 1, color: theme.colorScheme.outlineVariant),

          GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            onTap: _togglePanel,
            child: Container(
              color: theme.colorScheme.surfaceContainer,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: handleHeight,
                    width: double.infinity,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      border: Border(
                        top: BorderSide(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.5,
                          ),
                        ),
                      ),
                    ),
                    child: Container(
                      width: 32,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.4,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    height: _panelHeight,
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        height: _maxPanelHeight,
                        child: _rawUniqueChords.isEmpty
                            ? Center(
                                child: Text(
                                  "Загрузка...",
                                  style: theme.textTheme.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                controller: _chordScrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                scrollDirection: Axis.horizontal,
                                itemCount: _rawUniqueChords.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(width: 16),
                                itemBuilder: (context, index) {
                                  final rawName = _rawUniqueChords[index];
                                  final displayName =
                                      MusicTheory.transposeChord(
                                        rawName,
                                        _transposeLevel,
                                      );
                                  final positions = _getMockPositions(
                                    displayName,
                                  );

                                  return Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white.withOpacity(0.05)
                                          : Colors.black.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: GuitarChordWidget(
                                      chord: ChordData(displayName, positions),
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
  bool _showChords = true;
  List<SongLine> _parsedLines = [];
  bool _isLoading = true;
  bool _isError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.url == null) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isError = false;
    });

    try {
      final Uri uri = Uri.parse(
        '${AppConfig.baseUrl}/parse?url=${widget.url!}',
      );
      final response = await http.get(uri);

      if (response.statusCode == 200) {
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

        setState(() {
          _parsedLines = linesList
              .map((json) => SongLine.fromJson(json))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _isError = true;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 1. Сначала обрабатываем состояния загрузки и ошибки
    if (_isLoading) return const Center(child: CircularProgressIndicator());

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
            const Text("Ошибка загрузки"),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadData, child: const Text("Повторить")),
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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
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

                  // ЛОГИКА СКРЫТИЯ ROMAJI
                  // Используем hasRomaji, который мы объявили выше
                  if (hasRomaji) ...[
                    Text("Romaji", style: theme.textTheme.labelMedium),
                    Switch(
                      value: _showRomaji,
                      onChanged: (val) => setState(() => _showRomaji = val),
                    ),
                  ],
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
    return Column(
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
