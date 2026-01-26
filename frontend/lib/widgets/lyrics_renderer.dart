import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/music_theory.dart'; // Импортируем MusicTheory

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
