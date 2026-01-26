import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/song_models.dart'; // Импортируем модель ChordData

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
