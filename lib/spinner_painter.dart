import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpinnerPainter extends CustomPainter {
  final double angle;
  final double rpm;
  final double glowIntensity;
  final Color primaryColor;
  final Color secondaryColor;
  // Motion blur: geçmiş açıların listesi (en eskiden en yeniye)
  final List<double> trailAngles;

  SpinnerPainter({
    required this.angle,
    required this.rpm,
    required this.glowIntensity,
    required this.primaryColor,
    required this.secondaryColor,
    this.trailAngles = const [],
  });

  Color get _speedColor {
    if (rpm < 50) return primaryColor;
    if (rpm < 200) return Color.lerp(primaryColor, secondaryColor, (rpm - 50) / 150)!;
    if (rpm < 350) return secondaryColor;
    return Color.lerp(secondaryColor, Colors.white, ((rpm - 350) / 150).clamp(0, 1))!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 * 0.90;

    // ── Motion blur izleri (en eskiden en yeniye) ──
    if (rpm > 40 && trailAngles.isNotEmpty) {
      final trailCount = trailAngles.length;
      for (int t = 0; t < trailCount; t++) {
        final progress = (t + 1) / (trailCount + 1); // 0..1
        final opacity = progress * progress * 0.35 * (rpm / 300).clamp(0.0, 1.0);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(trailAngles[t]);
        _drawArmsTrail(canvas, R, opacity);
        canvas.restore();
      }
    }

    // ── Ana spinner ──
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    if (rpm > 20) _drawGlowAura(canvas, R);
    _drawArms(canvas, R);
    _drawArmBearings(canvas, R);
    _drawCenterHub(canvas, R);

    canvas.restore();

    if (rpm > 20) _drawOuterGlow(canvas, center, R * 1.05);
  }

  /// Sadece kolları yarı şeffaf çizer (trail için)
  void _drawArmsTrail(Canvas canvas, double R, double opacity) {
    final outerR = R * 0.72;
    final bearingR = R * 0.115;
    final color = primaryColor.withValues(alpha: opacity);

    for (int i = 0; i < 8; i++) {
      canvas.save();
      canvas.rotate((2 * math.pi / 8) * i);

      final path = _buildArmPath(R);
      canvas.drawPath(path, Paint()..color = color);

      // Bearing izi
      final bx = outerR * math.cos(0.18);
      final by = outerR * math.sin(0.18);
      canvas.drawCircle(
        Offset(bx, by), bearingR,
        Paint()..color = Colors.white.withValues(alpha: opacity * 0.8),
      );

      canvas.restore();
    }
  }

  void _drawGlowAura(Canvas canvas, double R) {
    final intensity = (rpm / 400).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset.zero, R,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.07 * glowIntensity * intensity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  void _drawArms(Canvas canvas, double R) {
    const numArms = 8;
    for (int i = 0; i < numArms; i++) {
      canvas.save();
      canvas.rotate((2 * math.pi / numArms) * i);
      _drawSingleArm(canvas, R);
      canvas.restore();
    }
  }

  /// Paylaşılan kol path'i (hem ana çizim hem trail için)
  Path _buildArmPath(double R) {
    final innerR = R * 0.19;
    final outerR = R * 0.72;
    final bearingR = R * 0.115;
    const sweep = 0.50;

    final path = Path();
    path.moveTo(innerR * math.cos(-sweep * 0.45),
        innerR * math.sin(-sweep * 0.45));
    path.cubicTo(
      innerR * 1.8,  -R * 0.08,
      outerR * 0.50, -R * 0.28,
      outerR * 0.82, -R * 0.22,
    );
    final bx = outerR * math.cos(sweep * 0.20);
    final by = outerR * math.sin(-sweep * 0.30);
    path.arcTo(
      Rect.fromCircle(center: Offset(bx, by), radius: bearingR),
      math.atan2(-R * 0.22 - by, outerR * 0.82 - bx) - 0.1,
      math.pi * 1.25,
      false,
    );
    path.cubicTo(
      outerR * 0.55, R * 0.24,
      innerR * 1.9,  R * 0.14,
      innerR * math.cos(sweep * 0.45),
      innerR * math.sin(sweep * 0.45),
    );
    path.arcTo(
      Rect.fromCircle(center: Offset.zero, radius: innerR),
      sweep * 0.45,
      -sweep * 0.90,
      false,
    );
    path.close();
    return path;
  }

  void _drawSingleArm(Canvas canvas, double R) {
    final path = _buildArmPath(R);
    final outerR = R * 0.72;

    final bounds = Rect.fromLTWH(-outerR * 0.2, -outerR * 0.5, outerR * 1.1, outerR * 0.9);
    final color = _speedColor;

    // Ana metalik dolgu
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.5, -1),
          end: const Alignment(0.5, 1),
          colors: [
            Color.lerp(color, Colors.white, 0.25)!,
            color,
            Color.lerp(color, Colors.black, 0.40)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds),
    );

    // Kafes doku (fotoğraftaki gibi diamond pattern)
    _drawDiamondMesh(canvas, path, R);

    // Üst highlight şeridi
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.22),
            Colors.transparent,
          ],
        ).createShader(bounds),
    );

    // Kenar
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
  }

  void _drawDiamondMesh(Canvas canvas, Path clipPath, double R) {
    canvas.save();
    canvas.clipPath(clipPath);

    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    const step = 9.0;
    // Diyagonal çizgiler (diamond doku)
    for (double d = -R; d < R * 2; d += step) {
      canvas.drawLine(Offset(d - R, -R), Offset(d + R, R), p);
      canvas.drawLine(Offset(d - R, R), Offset(d + R, -R), p);
    }

    canvas.restore();
  }

  void _drawArmBearings(Canvas canvas, double R) {
    const numArms = 8;
    final outerR = R * 0.72;
    final bearingR = R * 0.115;

    for (int i = 0; i < numArms; i++) {
      final baseAngle = (2 * math.pi / numArms) * i;
      // Bearing, kolun uç kısmında biraz sola kaymış
      final bAngle = baseAngle + 0.18;
      final bx = outerR * math.cos(bAngle);
      final by = outerR * math.sin(bAngle);
      final bc = Offset(bx, by);

      // Glow
      if (rpm > 60) {
        canvas.drawCircle(
          bc, bearingR * 1.5,
          Paint()
            ..color = _speedColor.withValues(alpha: 0.18 * glowIntensity)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }

      // Gümüş metalik dış çember
      canvas.drawCircle(
        bc, bearingR,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.38, -0.38),
            colors: [
              const Color(0xFFF0F0F0),
              const Color(0xFFAAAAAA),
              const Color(0xFF444444),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(Rect.fromCircle(center: bc, radius: bearingR)),
      );

      // İç halka (koyu)
      canvas.drawCircle(bc, bearingR * 0.62, Paint()..color = const Color(0xFF1A1A2E));

      // İç parlak nokta (ışık yansıması)
      canvas.drawCircle(
        bc + Offset(-bearingR * 0.22, -bearingR * 0.22),
        bearingR * 0.18,
        Paint()..color = Colors.white.withValues(alpha: 0.65),
      );

      // Kenar halkası
      canvas.drawCircle(
        bc, bearingR,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7,
      );
    }
  }

  void _drawCenterHub(Canvas canvas, double R) {
    final hubR = R * 0.17;

    // Hub glow
    if (rpm > 30) {
      canvas.drawCircle(
        Offset.zero, hubR * 1.7,
        Paint()
          ..color = _speedColor.withValues(alpha: 0.15 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // Krom dış halka
    canvas.drawCircle(
      Offset.zero, hubR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.35),
          colors: [
            Colors.white.withValues(alpha: 0.95),
            const Color(0xFFDDDDDD),
            const Color(0xFF888888),
            const Color(0xFF2A2A2A),
          ],
          stops: const [0.0, 0.25, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: hubR)),
    );

    // İç bearing yuvası
    canvas.drawCircle(Offset.zero, hubR * 0.63, Paint()..color = const Color(0xFF0D0D20));

    // Renkli iç bearing
    canvas.drawCircle(
      Offset.zero, hubR * 0.43,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: [
            Color.lerp(_speedColor, Colors.white, 0.3)!,
            _speedColor,
            Color.lerp(_speedColor, Colors.black, 0.4)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: hubR * 0.43)),
    );

    // Parlak yansıma noktası
    canvas.drawCircle(
      const Offset(-1.5, -1.5), hubR * 0.13,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );

    // Dış kenar
    canvas.drawCircle(
      Offset.zero, hubR,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawOuterGlow(Canvas canvas, Offset center, double R) {
    final intensity = (rpm / 500).clamp(0.0, 1.0);
    canvas.drawCircle(
      center, R,
      Paint()
        ..color = primaryColor.withValues(alpha: 0.2 * glowIntensity * intensity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 22 * intensity),
    );
  }

  @override
  bool shouldRepaint(SpinnerPainter old) =>
      old.trailAngles != trailAngles ||
      old.angle != angle ||
      old.rpm != rpm ||
      old.glowIntensity != glowIntensity ||
      old.primaryColor != primaryColor;
}
