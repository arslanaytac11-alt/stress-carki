import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'spinner_painter.dart';
import 'spinner_collection.dart';
import 'space_background_painter.dart';
import 'game_state.dart';
import 'l10n/app_localizations.dart';
import 'ad_manager.dart';

/// Uzay Orbit Modu — spinner uzay boşluğunda dairesel yörüngede hareket eder
/// ve aynı anda kendi ekseni etrafında döner. Parmakla her iki hareketi kontrol et.
class OrbitScreen extends StatefulWidget {
  final SpinnerModel spinnerModel;
  const OrbitScreen({super.key, required this.spinnerModel});

  @override
  State<OrbitScreen> createState() => _OrbitScreenState();
}

class _OrbitScreenState extends State<OrbitScreen>
    with TickerProviderStateMixin {
  late AnimationController _gameLoop;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // ── Orbit (dairesel yörünge) ──
  double _orbitAngle = 0.0;        // yörünge açısı (0–2π)
  double _orbitVelocity = 0.0;     // yörünge dönüş hızı
  double _orbitRadius = 100.0;     // yörünge yarıçapı

  // ── Spin (kendi ekseni) ──
  double _spinAngle = 0.0;
  double _spinVelocity = 0.0;

  // ── 3D Tilt (yukarı/aşağı eğilme) ──
  double _tiltX = 0.0;  // sağa-sola eğim
  double _tiltY = 0.0;  // yukarı-aşağı eğim

  // ── Dokunma kontrolü ──
  final Map<int, _TouchData> _touches = {};
  double _lastTwoFingerAngle = 0.0;
  bool _twoFingerActive = false;

  // ── Yıldız parçacıkları (orbit izi) ──
  final List<_OrbitTrail> _trails = [];

  // ── Skor ──
  double _totalSpins = 0.0;
  double _maxOrbitSpeed = 0.0;

  @override
  void initState() {
    super.initState();
    AdManager.instance.onScreenChange();
    GameState.instance.trackMode('orbit');
    _gameLoop = AnimationController(
      vsync: this, duration: const Duration(days: 1),
    )..addListener(_tick);

    _glowController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _gameLoop.forward();
  }

  DateTime _lastTick = DateTime.now();
  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;

    // ── Orbit fiziği ──
    _orbitAngle += _orbitVelocity * dt;
    _orbitVelocity *= 0.997; // hafif sürtünme
    if (_orbitVelocity.abs() < 0.01) _orbitVelocity = 0.0;

    // ── Spin fiziği ──
    _spinAngle += _spinVelocity * dt;
    _spinVelocity *= 0.995;
    if (_spinVelocity.abs() < 0.01) _spinVelocity = 0.0;

    // ── Tilt yavaşça sıfıra dön ──
    _tiltX *= 0.97;
    _tiltY *= 0.97;

    // ── Skor ──
    _totalSpins += _spinVelocity.abs() * dt / (2 * math.pi);
    final orbitRpm = (_orbitVelocity.abs() * 60) / (2 * math.pi);
    final spinRpm = (_spinVelocity.abs() * 60) / (2 * math.pi);
    if (orbitRpm > _maxOrbitSpeed) _maxOrbitSpeed = orbitRpm;
    // Global RPM biriktir
    if (orbitRpm + spinRpm > 5) {
      final earned = (orbitRpm + spinRpm) / 120.0;
      final newBadges = GameState.instance.addRpm(earned);
      if (newBadges.isNotEmpty && mounted) BadgeCelebration.show(context, newBadges.last);
    }

    // ── Orbit izi ──
    if (_orbitVelocity.abs() > 0.3) {
      final screenSize = MediaQuery.of(context).size;
      final cx = screenSize.width / 2;
      final cy = screenSize.height * 0.42;
      _trails.add(_OrbitTrail(
        x: cx + math.cos(_orbitAngle) * _orbitRadius,
        y: cy + math.sin(_orbitAngle) * _orbitRadius,
        life: 1.0,
        color: widget.spinnerModel.skin.colors[0],
      ));
    }
    // Trail yaşlandır
    for (int i = _trails.length - 1; i >= 0; i--) {
      _trails[i].life -= dt * 1.5;
      if (_trails[i].life <= 0) _trails.removeAt(i);
    }

    setState(() {});
  }

  void _onPointerDown(PointerDownEvent event) {
    _touches[event.pointer] = _TouchData(
      position: event.position,
      time: DateTime.now(),
    );
    if (_touches.length == 2) {
      _twoFingerActive = true;
      _lastTwoFingerAngle = _getTwoFingerAngle();
    }
    HapticFeedback.lightImpact();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final data = _touches[event.pointer];
    if (data == null) return;

    final now = DateTime.now();
    final dt = now.difference(data.time).inMicroseconds / 1e6;
    if (dt < 0.001 || dt > 0.1) {
      data.position = event.position;
      data.time = now;
      return;
    }

    if (_touches.length >= 2 && _twoFingerActive) {
      // ── İKİ PARMAK: döndürme → spin (kendi ekseni) ──
      final newAngle = _getTwoFingerAngle();
      var delta = newAngle - _lastTwoFingerAngle;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;

      _spinVelocity += (delta / dt) * 0.3;
      _spinVelocity = _spinVelocity.clamp(-40.0, 40.0);
      _lastTwoFingerAngle = newAngle;
    } else if (_touches.length == 1) {
      // ── TEK PARMAK: yatay → orbit, dikey → 3D tilt ──
      final dx = event.position.dx - data.position.dx;
      final dy = event.position.dy - data.position.dy;

      // Orbit (yatay)
      final pushX = dx / (dt * 60.0);
      _orbitVelocity += pushX * 0.015;
      _orbitVelocity = _orbitVelocity.clamp(-8.0, 8.0);

      // 3D Tilt (dikey) — yumuşak geçiş
      _tiltY += dy * 0.008;
      _tiltY = _tiltY.clamp(-1.2, 1.2);
      _tiltX += dx * 0.005;
      _tiltX = _tiltX.clamp(-1.2, 1.2);
    }

    data.lastVelocity = event.position - data.position;
    data.position = event.position;
    data.time = now;
  }

  void _onPointerUp(PointerUpEvent event) {
    final data = _touches.remove(event.pointer);
    if (data != null && _touches.isEmpty) {
      // Flik boost — tek parmak orbit
      final vx = data.lastVelocity.dx;
      _orbitVelocity += vx * 0.01;
      _orbitVelocity = _orbitVelocity.clamp(-8.0, 8.0);
    }
    if (_touches.length < 2) _twoFingerActive = false;
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _touches.remove(event.pointer);
    if (_touches.length < 2) _twoFingerActive = false;
  }

  double _getTwoFingerAngle() {
    final pts = _touches.values.toList();
    if (pts.length < 2) return 0.0;
    final dx = pts[1].position.dx - pts[0].position.dx;
    final dy = pts[1].position.dy - pts[0].position.dy;
    return math.atan2(dy, dx);
  }

  @override
  void dispose() {
    GameState.instance.save();
    _gameLoop.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.spinnerModel.skin.colors;
    final screenSize = MediaQuery.of(context).size;
    final cx = screenSize.width / 2;
    final cy = screenSize.height * 0.42;

    // Spinner pozisyonu
    final spinnerX = cx + math.cos(_orbitAngle) * _orbitRadius;
    final spinnerY = cy + math.sin(_orbitAngle) * _orbitRadius;

    final orbitRpm = (_orbitVelocity.abs() * 60) / (2 * math.pi);
    final spinRpm = (_spinVelocity.abs() * 60) / (2 * math.pi);

    return Scaffold(
      backgroundColor: const Color(0xFF03020F),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Arka plan
            RepaintBoundary(
              child: CustomPaint(
                size: screenSize,
                painter: const SpaceBackgroundPainter(),
              ),
            ),
            // Renkli tint
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      (spinnerX - cx) / (screenSize.width / 2),
                      (spinnerY - cy) / (screenSize.height / 2),
                    ),
                    radius: 0.5,
                    colors: [
                      colors[0].withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // ── Orbit yolu (noktalı daire) ──
            CustomPaint(
              size: screenSize,
              painter: _OrbitPathPainter(
                cx: cx, cy: cy, radius: _orbitRadius, color: colors[0],
              ),
            ),
            // ── Trail parçacıkları ──
            CustomPaint(
              size: screenSize,
              painter: _TrailPainter(_trails),
            ),
            // ── Spinner ──
            Positioned(
              left: spinnerX - 75,
              top: spinnerY - 75,
              child: AnimatedBuilder(
                animation: _glowController,
                builder: (context, _) {
                  final matrix = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015) // perspektif
                    ..rotateX(_tiltY * 0.8)   // yukarı-aşağı eğim
                    ..rotateY(-_tiltX * 0.8)  // sağa-sola eğim
                    ..rotateZ(_spinAngle);    // kendi ekseni
                  return Transform(
                    transform: matrix,
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: const Size(150, 150),
                      painter: SpinnerPainter(
                        angle: _spinAngle,
                        rpm: spinRpm,
                        glowIntensity: spinRpm > 5 ? _glowAnimation.value : 0.15,
                        primaryColor: colors[0],
                        secondaryColor: colors[1],
                        trailAngles: [],
                      ),
                    ),
                  );
                },
              ),
            ),
            // ── Üst bar ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(AppLocalizations.of(context)!.orbitTitle, style: TextStyle(
                      foreground: Paint()..shader = const LinearGradient(
                        colors: [Color(0xFF00E5FF), Color(0xFF651FFF)],
                      ).createShader(const Rect.fromLTWH(0, 0, 150, 25)),
                      fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3,
                    )),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
                      ),
                      child: Text(AppLocalizations.of(context)!.orbitSpins(_totalSpins.toStringAsFixed(0)),
                        style: const TextStyle(color: Color(0xFF00E5FF),
                            fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            // ── Alt bilgi kartı ──
            Positioned(
              left: 16, right: 16, bottom: 74,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _infoCol('🌀', 'Orbit', '${orbitRpm.toStringAsFixed(0)} RPM',
                        const Color(0xFF00E5FF)),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _infoCol('💫', 'Spin', '${spinRpm.toStringAsFixed(0)} RPM',
                        const Color(0xFFAA00FF)),
                    Container(width: 1, height: 40, color: Colors.white10),
                    _infoCol('🏆', 'Maks', '${_maxOrbitSpeed.toStringAsFixed(0)}',
                        const Color(0xFFFFD700)),
                  ],
                ),
              ),
            ),
            // ── Kontrol ipucu ──
            Positioned(
              left: 0, right: 0, bottom: 150,
              child: AnimatedOpacity(
                opacity: _totalSpins < 3 ? 0.6 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: const Text(
                  '← → Orbit   ↑ ↓ Spin',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white38, fontSize: 13,
                      letterSpacing: 2),
                ),
              ),
            ),
            // ── Banner reklam ──
            const Positioned(
              left: 0, right: 0, bottom: 0,
              child: BannerAdWidget(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCol(String emoji, String label, String value, Color color) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(
          color: color, fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Touch verisi ──
class _TouchData {
  Offset position;
  DateTime time;
  Offset lastVelocity;
  _TouchData({required this.position, required this.time, this.lastVelocity = Offset.zero});
}

// ── Trail parçacığı ──
class _OrbitTrail {
  double x, y, life;
  Color color;
  _OrbitTrail({required this.x, required this.y, required this.life, required this.color});
}

// ── Orbit yolu çizici (noktalı daire) ──
class _OrbitPathPainter extends CustomPainter {
  final double cx, cy, radius;
  final Color color;
  _OrbitPathPainter({required this.cx, required this.cy, required this.radius, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Noktalı daire
    const segments = 60;
    for (int i = 0; i < segments; i++) {
      if (i % 2 == 0) {
        final startAngle = (i / segments) * 2 * math.pi;
        final sweepAngle = (1 / segments) * 2 * math.pi;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: radius),
          startAngle, sweepAngle, false, paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPathPainter old) =>
      cx != old.cx || cy != old.cy || radius != old.radius;
}

// ── Trail çizici ──
class _TrailPainter extends CustomPainter {
  final List<_OrbitTrail> trails;
  _TrailPainter(this.trails);

  @override
  void paint(Canvas canvas, Size size) {
    for (final t in trails) {
      final paint = Paint()
        ..color = t.color.withValues(alpha: t.life * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + (1 - t.life) * 4);
      canvas.drawCircle(Offset(t.x, t.y), 2 + t.life * 3, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => true;
}
