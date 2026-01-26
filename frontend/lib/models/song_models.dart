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
