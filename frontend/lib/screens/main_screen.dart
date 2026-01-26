import 'dart:io';
import 'package:flutter/foundation.dart'; // Для kIsWeb
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../widgets/adaptive_song_card.dart';
import 'home_tab.dart';
import 'search_screen.dart';
import 'song_view_screen.dart';

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
                // Проверяем наличие ключа, так как старые сохранения могут его не иметь
                source: song.containsKey('source_label')
                    ? song['source_label']
                    : null,
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
