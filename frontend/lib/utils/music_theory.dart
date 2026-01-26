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
