import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Hilal arc metin çizici — opacity yok, FadeTransition GPU'da yönetir.
/// Sadece text veya color değişince paint() çağrılır. Fade sırasında SIFIR CPU işi.
class QuoteArcPainter extends CustomPainter {
  final String text;
  final Color color;

  static String? _cText;
  static Color? _cColor;
  static List<TextPainter> _cPainters = [];
  static List<double> _cWidths = [];
  static double _cTotalWidth = 0;

  QuoteArcPainter({required this.text, required this.color}) {
    if (text != _cText || color != _cColor) {
      _rebuild(text, color);
    }
  }

  static void prewarm(String text, Color color) {
    if (text != _cText || color != _cColor) {
      _rebuild(text, color);
    }
  }

  static void _rebuild(String text, Color color) {
    _cText = text;
    _cColor = color;
    _cPainters = [];
    _cWidths = [];
    _cTotalWidth = 0;

    final baseColor = Color.lerp(Colors.white, color, 0.45)!;
    final style = TextStyle(
      fontSize: 14.5,
      color: baseColor,
      fontWeight: FontWeight.w300,
      fontStyle: FontStyle.italic,
      letterSpacing: 2.0,
      height: 1.0,
      shadows: [
        Shadow(color: color.withValues(alpha: 0.6), blurRadius: 10),
        Shadow(color: color.withValues(alpha: 0.3), blurRadius: 22),
      ],
    );

    for (final ch in text.characters) {
      final tp = TextPainter(
        text: TextSpan(text: ch, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _cPainters.add(tp);
      _cWidths.add(tp.width);
      _cTotalWidth += tp.width;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (_cPainters.isEmpty) return;

    const double radius = 164.0;
    final cx = size.width / 2;
    final cy = size.height / 2;

    final totalArcAngle = _cTotalWidth / radius;
    double angle = -math.pi / 2 - totalArcAngle / 2;

    for (int i = 0; i < _cPainters.length; i++) {
      final tp = _cPainters[i];
      final charMid = angle + (_cWidths[i] / 2) / radius;
      canvas.save();
      canvas.translate(
        cx + radius * math.cos(charMid),
        cy + radius * math.sin(charMid),
      );
      canvas.rotate(charMid + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      angle += _cWidths[i] / radius;
    }
  }

  @override
  bool shouldRepaint(QuoteArcPainter old) =>
      old.text != text || old.color != color;
}
