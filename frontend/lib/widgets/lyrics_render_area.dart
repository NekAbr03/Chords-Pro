import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/app_config.dart';
import '../models/song_models.dart';
import '../services/cache_service.dart'; // Импорт CacheService
import 'lyrics_renderer.dart';

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

  // Вспомогательный метод для обработки JSON (чтобы не дублировать код)
  void _processJsonData(Map<String, dynamic> decodedMap) {
    final List<dynamic> linesList = decodedMap['lines'];

    // Логика извлечения уникальных аккордов
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

    // Передаем аккорды наверх (в SongViewScreen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onChordsLoaded?.call(orderedChords);
      }
    });

    setState(() {
      _parsedLines = linesList.map((json) => SongLine.fromJson(json)).toList();
    });
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

    // 1. Проверяем кэш
    final cachedData = CacheService.getSongData(widget.url!);
    if (cachedData != null) {
      // Если есть в кэше, показываем сразу
      _processJsonData(cachedData);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isError = false;
          _isSlowLoading = false;
        });
      }
    }

    // 2. Если данных все еще нет (кэш пуст), включаем загрузку и таймер
    if (_parsedLines.isEmpty) {
      setState(() {
        _isLoading = true;
        _isError = false;
        _isSlowLoading = false;
        _errorMessage = null;
      });

      // Запускаем таймер только если мы реально ждем (нет кэша)
      _loadingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _isLoading) {
          setState(() => _isSlowLoading = true);
        }
      });
    }

    try {
      final url = '${AppConfig.baseUrl}/parse?url=${widget.url!}';
      final response = await AppConfig.getWithRetry(url).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw TimeoutException('Сервер не отвечает'),
      );

      _loadingTimer?.cancel();

      final Map<String, dynamic> freshData = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      // 3. Сохраняем в кэш
      await CacheService.saveSongData(widget.url!, freshData);

      if (mounted) {
        _processJsonData(freshData);
        setState(() {
          _isLoading = false;
          _isSlowLoading = false;
        });
      }
    } catch (e) {
      _loadingTimer?.cancel();
      if (mounted) {
        // 4. ЕСЛИ ОШИБКА СЕТИ
        if (_parsedLines.isNotEmpty) {
          // Если данные уже есть (из кэша)
          setState(() => _isLoading = false);

          // --- ВОТ ЭТО ДОБАВЛЯЕМ ДЛЯ УВЕДОМЛЕНИЯ ---
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Нет сети. Показана сохраненная версия."),
              duration: Duration(seconds: 3),
              behavior: SnackBarBehavior.floating, // Чтобы плавал над кнопками
            ),
          );
          // ------------------------------------------
        } else {
          // Если данных нет вообще - показываем ошибку
          setState(() {
            _isLoading = false;
            _isError = true;
            _isSlowLoading = false;
            if (e is SocketException) {
              _errorMessage = 'Нет подключения к интернету';
            } else if (e is TimeoutException) {
              _errorMessage = 'Сервер не отвечает';
            } else {
              _errorMessage = 'Ошибка загрузки';
            }
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Показываем загрузку только если данных нет совсем
    if (_isLoading && _parsedLines.isEmpty) {
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

    // Показываем ошибку только если данных нет совсем
    if (_isError && _parsedLines.isEmpty) {
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

    final bool hasRomaji = _parsedLines.any((line) {
      final String r = line.romaji.trim();
      final String o = line.original.trim();
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
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
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
                ],
              ),
            );
          }

          final lineData = _parsedLines[index - 1];
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
