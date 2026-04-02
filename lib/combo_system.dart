import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Combo seviyeleri
enum ComboLevel { none, x2, x3, x5, max }

extension ComboLevelInfo on ComboLevel {
  String get label {
    switch (this) {
      case ComboLevel.none: return '';
      case ComboLevel.x2: return 'COMBO x2';
      case ComboLevel.x3: return 'COMBO x3 🔥';
      case ComboLevel.x5: return 'COMBO x5 💥';
      case ComboLevel.max: return 'MAX COMBO ⚡';
    }
  }
  Color get color {
    switch (this) {
      case ComboLevel.none: return Colors.transparent;
      case ComboLevel.x2: return const Color(0xFF29B6F6);
      case ComboLevel.x3: return const Color(0xFFFF9800);
      case ComboLevel.x5: return const Color(0xFFE91E63);
      case ComboLevel.max: return const Color(0xFFFFD700);
    }
  }
  double get rpmThreshold {
    switch (this) {
      case ComboLevel.none: return 0;
      case ComboLevel.x2: return 80;
      case ComboLevel.x3: return 150;
      case ComboLevel.x5: return 230;
      case ComboLevel.max: return 300;
    }
  }
}

class ComboSystem {
  ComboLevel _level = ComboLevel.none;
  double _sustainTimer = 0.0;
  static const double _sustainRequired = 2.5; // saniye

  ComboLevel get level => _level;
  bool _justLeveledUp = false;
  bool get justLeveledUp {
    if (_justLeveledUp) { _justLeveledUp = false; return true; }
    return false;
  }

  void update(double rpm, double dt) {
    final targetLevel = _computeLevel(rpm);

    if (targetLevel.index > _level.index) {
      _sustainTimer += dt;
      if (_sustainTimer >= _sustainRequired) {
        _level = targetLevel;
        _sustainTimer = 0;
        _justLeveledUp = true;
      }
    } else if (targetLevel.index < _level.index) {
      // Hız düşünce combo sıfırlanır
      _sustainTimer = 0;
      _level = targetLevel;
    } else {
      _sustainTimer = 0;
    }
  }

  ComboLevel _computeLevel(double rpm) {
    if (rpm >= ComboLevel.max.rpmThreshold) return ComboLevel.max;
    if (rpm >= ComboLevel.x5.rpmThreshold) return ComboLevel.x5;
    if (rpm >= ComboLevel.x3.rpmThreshold) return ComboLevel.x3;
    if (rpm >= ComboLevel.x2.rpmThreshold) return ComboLevel.x2;
    return ComboLevel.none;
  }

  void reset() {
    _level = ComboLevel.none;
    _sustainTimer = 0;
  }
}

/// Confetti parçacığı
class ConfettiParticle {
  double x, y, vx, vy, rotation, rotSpeed, size;
  Color color;
  double life;

  ConfettiParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.rotation, required this.rotSpeed,
    required this.size, required this.color,
    this.life = 1.0,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 200 * dt; // yerçekimi
    vx *= 0.99;
    rotation += rotSpeed * dt;
    life -= dt * 0.7;
  }

  bool get isDead => life <= 0;
}

class ConfettiSystem {
  final List<ConfettiParticle> particles = [];
  final _rand = math.Random();

  static const _colors = [
    Color(0xFFFFD700), Color(0xFFE91E63), Color(0xFF00BCD4),
    Color(0xFF4CAF50), Color(0xFFFF9800), Color(0xFF9C27B0),
    Color(0xFF2196F3), Color(0xFFFF5722),
  ];

  void burst(double cx, double cy, {int count = 60}) {
    for (int i = 0; i < count; i++) {
      final angle = _rand.nextDouble() * 2 * math.pi;
      final speed = 200 + _rand.nextDouble() * 400;
      particles.add(ConfettiParticle(
        x: cx + (_rand.nextDouble() - 0.5) * 40,
        y: cy + (_rand.nextDouble() - 0.5) * 40,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 300,
        rotation: _rand.nextDouble() * math.pi * 2,
        rotSpeed: (_rand.nextDouble() - 0.5) * 15,
        size: 4 + _rand.nextDouble() * 8,
        color: _colors[_rand.nextInt(_colors.length)],
      ));
    }
  }

  void update(double dt) {
    particles.removeWhere((p) => p.isDead);
    for (final p in particles) { p.update(dt); }
  }
}

class ConfettiPainter extends CustomPainter {
  final ConfettiSystem system;
  ConfettiPainter(this.system);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in system.particles) {
      final paint = Paint()..color = p.color.withValues(alpha: p.life.clamp(0, 1));
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      // Dikdörtgen confetti parçası
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) => true;
}
