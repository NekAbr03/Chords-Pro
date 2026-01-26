import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../utils/music_theory.dart';
import '../models/song_models.dart';
import '../widgets/lyrics_render_area.dart';
import '../widgets/guitar_chord_widget.dart';

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

  void _scrollToChord(String rawChordName) {
    if (_rawUniqueChords.isEmpty) return;
    final index = _rawUniqueChords.indexOf(rawChordName);

    if (index != -1) {
      const itemWidth = 96.0;
      final screenWidth = MediaQuery.of(context).size.width;
      final targetOffset =
          (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

      if (_chordScrollController.hasClients) {
        final maxScroll = _chordScrollController.position.maxScrollExtent;
        _chordScrollController.animateTo(
          targetOffset.clamp(0.0, maxScroll),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
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
    setState(() => _isPanelExpanded = true);
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
                  // FIX: Проверяем, жив ли экран
                  if (mounted) {
                    setState(() => _rawUniqueChords = chords);
                  }
                }
              },
              onChordTap: _onChordTapInternal,
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
