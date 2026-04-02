import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Galaxy arka plan — bir kez çizilir, GPU'da cache'lenir, hiç yeniden boyanmaz.
class SpaceBackgroundPainter extends CustomPainter {
  const SpaceBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Derin uzay tabanı ──
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03020F), Color(0xFF07051A), Color(0xFF0A0620)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), bgPaint);

    // ── Nebula lekeleri ──
    _nebula(canvas, Offset(w * 0.15, h * 0.25), 180, const Color(0xFF5500BB), 0.065);
    _nebula(canvas, Offset(w * 0.85, h * 0.15), 140, const Color(0xFF0044FF), 0.058);
    _nebula(canvas, Offset(w * 0.55, h * 0.72), 200, const Color(0xFF00AAFF), 0.048);
    _nebula(canvas, Offset(w * 0.75, h * 0.55), 110, const Color(0xFFCC0066), 0.042);
    _nebula(canvas, Offset(w * 0.30, h * 0.80), 130, const Color(0xFF003388), 0.050);

    // ── Sütlüyol bandı ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.transparent,
            Colors.white.withValues(alpha: 0.018),
            Colors.white.withValues(alpha: 0.026),
            Colors.white.withValues(alpha: 0.018),
            Colors.transparent,
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, w, h))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );

    // ── Küçük yıldızlar ──
    final rand = math.Random(42);
    final dotPaint = Paint();
    for (int i = 0; i < 220; i++) {
      final x = rand.nextDouble() * w;
      final y = rand.nextDouble() * h;
      final r = rand.nextDouble() * 1.3 + 0.2;
      dotPaint.color = Colors.white.withValues(alpha: rand.nextDouble() * 0.55 + 0.25);
      canvas.drawCircle(Offset(x, y), r, dotPaint);
    }

    // ── Parlak yıldızlar (glow'lu) ──
    final bRand = math.Random(77);
    for (int i = 0; i < 18; i++) {
      final x = bRand.nextDouble() * w;
      final y = bRand.nextDouble() * h;
      final brightness = bRand.nextDouble() * 0.4 + 0.6;
      final glowSize = bRand.nextDouble() * 3.0 + 2.5;
      canvas.drawCircle(Offset(x, y), glowSize,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.06 * brightness)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
      canvas.drawCircle(Offset(x, y), 1.3,
          Paint()..color = Colors.white.withValues(alpha: 0.85 * brightness));
    }
  }

  void _nebula(Canvas canvas, Offset center, double radius, Color color, double opacity) {
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(center, radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: opacity), Colors.transparent],
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 35));
  }

  @override
  bool shouldRepaint(SpaceBackgroundPainter old) => false; // Asla yeniden boyanmaz
}
