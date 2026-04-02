import 'dart:math' as math;
import 'package:flutter/material.dart';

class Particle {
  double x, y;
  double vx, vy;
  double life; // 0.0 - 1.0
  double size;
  Color color;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    this.life = 1.0,
    this.size = 4.0,
  });

  void update(double dt) {
    x += vx * dt;
    y += vy * dt;
    vy += 80 * dt; // Yerçekimi
    life -= dt * 1.5;
    size *= 0.99;
  }

  bool get isDead => life <= 0 || size < 0.5;
}

class ParticleSystem {
  final List<Particle> particles = [];
  final math.Random _rand = math.Random();

  void emit(double x, double y, double rpm, Color color) {
    if (rpm < 100) return;
    final count = (rpm / 100).floor().clamp(1, 5);
    for (int i = 0; i < count; i++) {
      final angle = _rand.nextDouble() * 2 * math.pi;
      final speed = 50.0 + _rand.nextDouble() * 100;
      particles.add(Particle(
        x: x + (_rand.nextDouble() - 0.5) * 60,
        y: y + (_rand.nextDouble() - 0.5) * 60,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 50,
        color: color,
        size: 2.0 + _rand.nextDouble() * 4,
      ));
    }
    // Temizle (max 200 parçacık)
    if (particles.length > 200) {
      particles.removeRange(0, particles.length - 200);
    }
  }

  void update(double dt) {
    particles.removeWhere((p) => p.isDead);
    for (final p in particles) {
      p.update(dt);
    }
  }
}

class ParticlePainter extends CustomPainter {
  final ParticleSystem system;

  ParticlePainter(this.system);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in system.particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0.0, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter old) => true;
}
