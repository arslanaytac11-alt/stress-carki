import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_state.dart';
import 'ad_manager.dart';

import 'l10n/app_localizations.dart';

// ════════════════════════════════════════════════════════════════════
//  STRES TOPU — Dokunmatik Sıkma + Jelly Physics
// ════════════════════════════════════════════════════════════════════

class StressBallScreen extends StatefulWidget {
  const StressBallScreen({super.key});
  @override
  State<StressBallScreen> createState() => _StressBallScreenState();
}

class _StressBallScreenState extends State<StressBallScreen>
    with TickerProviderStateMixin {

  double _baseRadius = 0;
  Offset _ballCenter = Offset.zero;
  late Size _screenSize;
  bool _layoutDone = false;

  // ── Multi-touch parmaklar ──
  final Map<int, Offset> _fingers = {};
  final Map<int, Offset> _fingerStarts = {};
  final Map<int, double> _fingerMoveDist = {}; // ne kadar hareket etti

  // ── Jelly mesh: 32 nokta ──
  static const int _N = 32;
  final List<double> _meshR = List.filled(_N, 0);
  final List<double> _meshV = List.filled(_N, 0);

  // ── Top pozisyon fiziği ──
  Offset _ballVelocity = Offset.zero;
  bool _isDragging = false;
  int? _dragPointer;
  Offset _dragOffset = Offset.zero; // parmak-top merkez farkı

  // ── Görsel ──
  double _faceEmotion = 0;
  double _wobble = 0;
  int _squeezeCount = 0;
  double _currentPressure = 0;

  // ── Parçacıklar ──
  final List<_Particle> _particles = [];
  final _rng = math.Random();

  // ── Loop ──
  late AnimationController _loopCtrl;
  DateTime _lastTick = DateTime.now();

  // ── Renkler ──
  static const _blue2 = Color(0xFF2962FF);
  static const _accent = Color(0xFF82B1FF);

  // ── İkonlar ──
  static const _deco = [
    Icons.gamepad, Icons.sports_esports, Icons.settings,
    Icons.nightlight_round, Icons.star_rounded, Icons.extension,
    Icons.auto_awesome, Icons.psychology,
  ];

  @override
  void initState() {
    super.initState();
    AdManager.instance.onScreenChange();
    GameState.instance.trackMode('stressball');
    _loopCtrl = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)..forward();
  }

  @override
  void dispose() {
    _loopCtrl.dispose();
    GameState.instance.save();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════
  //  GAME LOOP
  // ════════════════════════════════════════════════════════════════

  void _tick() {
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;
    if (!_layoutDone) return;

    _wobble += dt * 3;

    // ── 1) Her parmak için mesh'e güçlü kuvvet uygula ──
    _currentPressure = 0;
    for (final finger in _fingers.values) {
      _applyFingerToMesh(finger, dt);
    }

    // ── 2) İki parmak sıkıştırma (pinch) ──
    if (_fingers.length >= 2) {
      _applyPinchForce(dt);
    }

    // ── 3) Spring-damper fiziği ──
    _solveMeshPhysics(dt);

    // ── 4) Yüz ──
    final targetEmo = _currentPressure.clamp(0.0, 1.0);
    _faceEmotion += (targetEmo - _faceEmotion) * dt * 10;

    // ── 5) Top pozisyon fiziği ──
    _updateBallPosition(dt);

    // ── 5b) HARD CLAMP — top kesinlikle ekranda kalsın ──
    final safeMinX = _baseRadius * 0.3;
    final safeMaxX = _screenSize.width - _baseRadius * 0.3;
    final safeMinY = _baseRadius * 0.3;
    final safeMaxY = _screenSize.height - _baseRadius * 0.3;
    _ballCenter = Offset(
      _ballCenter.dx.clamp(safeMinX, safeMaxX),
      _ballCenter.dy.clamp(safeMinY, safeMaxY),
    );
    // Velocity sınırlama
    final maxV = 2000.0;
    if (_ballVelocity.dx.abs() > maxV || _ballVelocity.dy.abs() > maxV) {
      _ballVelocity = Offset(
        _ballVelocity.dx.clamp(-maxV, maxV),
        _ballVelocity.dy.clamp(-maxV, maxV),
      );
    }

    // ── 6) RPM ──
    if (_currentPressure > 0.05) {
      final rpm = _currentPressure * dt * 100;
      final newBadges = GameState.instance.addRpm(rpm);
      if (newBadges.isNotEmpty && mounted) {
        BadgeCelebration.show(context, newBadges.last);
      }
    }

    // ── 7) Parçacıklar ──
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 200 * dt;
      p.life -= dt;
      if (p.life <= 0) _particles.removeAt(i);
    }
    if (_particles.length > 100) _particles.removeRange(0, _particles.length - 100);

    setState(() {});
  }

  void _applyFingerToMesh(Offset finger, double dt) {
    final dx = finger.dx - _ballCenter.dx;
    final dy = finger.dy - _ballCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final angle = math.atan2(dy, dx);

    // Parmak topun dışındaysa etki yok
    if (dist > _baseRadius * 1.5) return;

    // Basınç hesapla — kenardan bastığında daha fazla, merkezden daha az deformasyon
    final edgeFactor = (dist / _baseRadius).clamp(0.1, 1.0); // Kenarda 1, merkezde 0.1
    final penetration = (((_baseRadius * 1.4) - dist) / _baseRadius).clamp(0.0, 1.0);
    if (penetration <= 0) return;

    _currentPressure = math.max(_currentPressure, penetration);

    for (int i = 0; i < _N; i++) {
      final meshAngle = (i / _N) * math.pi * 2;
      final angleDiff = _angleDiff(meshAngle, angle);
      final absDiff = angleDiff.abs();

      if (absDiff < math.pi * 0.55) {
        // Sıkılan bölge — kenardan basınca daha çok ezilir
        final influence = math.pow(math.cos(absDiff * 0.9), 2.0).toDouble();
        final maxDeform = _baseRadius * 0.45 * edgeFactor; // Merkezde az, kenarda çok
        final target = -penetration * maxDeform * influence;
        _meshR[i] += (target - _meshR[i]) * dt * 25;
        _meshV[i] *= 0.75;
      } else if (absDiff > math.pi * 0.6) {
        // Karşı taraf — hacim korunumu ile dışarı şişme
        final oppInfluence = math.pow(math.cos((math.pi - absDiff) * 0.6), 1.5).toDouble();
        final target = penetration * _baseRadius * 0.12 * oppInfluence * edgeFactor;
        _meshR[i] += (target - _meshR[i]) * dt * 18;
      }
    }

    // Parçacıklar — sadece kenarda basınca
    if (penetration > 0.2 && edgeFactor > 0.3 && _rng.nextDouble() < penetration * 0.5) {
      _spawnParticle(finger, angle, penetration);
    }
  }

  void _applyPinchForce(double dt) {
    // İki parmak arası mesafe azalınca topu sıkıştır
    final fingerList = _fingers.values.toList();
    final f1 = fingerList[0];
    final f2 = fingerList[1];

    final pinchDist = (f1 - f2).distance;
    final pinchAngle = math.atan2(f2.dy - f1.dy, f2.dx - f1.dx);

    // Sıkıştırma miktarı: parmaklar yaklaştıkça daha çok
    final maxDist = _baseRadius * 3;
    final pinchAmount = ((maxDist - pinchDist) / maxDist).clamp(0.0, 1.0);

    if (pinchAmount > 0.1) {
      _currentPressure = math.max(_currentPressure, pinchAmount * 1.5);

      // İki tarafı da içeri it, dik ekseni dışarı şişir
      for (int i = 0; i < _N; i++) {
        final meshAngle = (i / _N) * math.pi * 2;

        // Sıkıştırma ekseni boyunca
        final diffToAxis = _angleDiff(meshAngle, pinchAngle).abs();
        final diffToPerp = _angleDiff(meshAngle, pinchAngle + math.pi / 2).abs();

        // Sıkma ekseninde içeri — daha güçlü
        if (diffToAxis < math.pi * 0.5 || (math.pi - diffToAxis) < math.pi * 0.5) {
          final influence = math.pow(math.cos(diffToAxis), 1.5).toDouble();
          final target = -pinchAmount * _baseRadius * 0.6 * influence;
          _meshR[i] += (target - _meshR[i]) * dt * 30;
        }

        // Dik eksende dışarı — daha belirgin şişme
        if (diffToPerp < math.pi * 0.5) {
          final influence = math.pow(math.cos(diffToPerp), 1.5).toDouble();
          final target = pinchAmount * _baseRadius * 0.12 * influence;
          _meshR[i] += (target - _meshR[i]) * dt * 25;
        }
      }
    }
  }

  void _updateBallPosition(double dt) {
    final minX = _baseRadius * 0.5;
    final maxX = _screenSize.width - _baseRadius * 0.5;
    final minY = _baseRadius * 0.5 + 80;
    final maxY = _screenSize.height - _baseRadius * 0.5 - 40;

    if (_isDragging && _dragPointer != null && _fingers.containsKey(_dragPointer)) {
      final finger = _fingers[_dragPointer]!;
      final target = finger - _dragOffset;
      final diff = target - _ballCenter;
      _ballVelocity = diff * 10;
      _ballCenter += diff * dt * 15;
    } else {
      // Yerçekimi — zemine oturunca durdur
      if (_ballCenter.dy < maxY - 1 || _ballVelocity.dy.abs() > 5) {
        _ballVelocity += Offset(0, 600 * dt);
      }
      _ballCenter += _ballVelocity * dt;

      // Sürtünme
      _ballVelocity *= math.pow(0.97, dt * 60).toDouble();

      // Çok yavaşsa durdur
      if (_ballVelocity.distance < 2 && (_ballCenter.dy - maxY).abs() < 2) {
        _ballVelocity = Offset.zero;
      }
    }

    // Sınır kontrolü — HER ZAMAN uygula (sürükleme dahil)
    if (_ballCenter.dx < minX) {
      _ballCenter = Offset(minX, _ballCenter.dy);
      _ballVelocity = Offset(-_ballVelocity.dx * 0.5, _ballVelocity.dy);
      _addBounceWobble(math.pi);
    } else if (_ballCenter.dx > maxX) {
      _ballCenter = Offset(maxX, _ballCenter.dy);
      _ballVelocity = Offset(-_ballVelocity.dx * 0.5, _ballVelocity.dy);
      _addBounceWobble(0);
    }
    if (_ballCenter.dy < minY) {
      _ballCenter = Offset(_ballCenter.dx, minY);
      _ballVelocity = Offset(_ballVelocity.dx, -_ballVelocity.dy * 0.5);
      _addBounceWobble(-math.pi / 2);
    } else if (_ballCenter.dy > maxY) {
      _ballCenter = Offset(_ballCenter.dx, maxY);
      _ballVelocity = Offset(_ballVelocity.dx * 0.95, -_ballVelocity.dy * 0.6);
      _addBounceWobble(math.pi / 2);
      if (_ballVelocity.dy.abs() > 80) HapticFeedback.lightImpact();
    }

    // NaN/Infinity koruması
    if (_ballCenter.dx.isNaN || _ballCenter.dy.isNaN ||
        _ballCenter.dx.isInfinite || _ballCenter.dy.isInfinite ||
        _ballVelocity.dx.isNaN || _ballVelocity.dy.isNaN) {
      _ballCenter = Offset(_screenSize.width / 2, _screenSize.height * 0.44);
      _ballVelocity = Offset.zero;
      for (int i = 0; i < _N; i++) { _meshR[i] = 0; _meshV[i] = 0; }
    }
  }

  void _addBounceWobble(double angle) {
    for (int i = 0; i < _N; i++) {
      final meshAngle = (i / _N) * math.pi * 2;
      final diff = _angleDiff(meshAngle, angle).abs();
      final influence = math.pow(math.cos(diff * 0.5), 3).toDouble();
      _meshV[i] += -influence * _baseRadius * 0.2;
    }
  }

  void _solveMeshPhysics(double dt) {
    const stiffness = 55.0;
    const damping = 5.0;
    const neighbor = 30.0;

    final maxInward = -_baseRadius * 0.35; // Maksimum içeri deformasyon
    final maxOutward = _baseRadius * 0.15; // Maksimum dışarı şişme — çok az

    for (int i = 0; i < _N; i++) {
      final spring = -stiffness * _meshR[i];
      final damp = -damping * _meshV[i];
      final prev = _meshR[(i - 1 + _N) % _N];
      final next = _meshR[(i + 1) % _N];
      final nbr = neighbor * (prev + next - 2 * _meshR[i]);

      _meshV[i] += (spring + damp + nbr) * dt;
      _meshR[i] += _meshV[i] * dt;

      // HARD LIMIT — top asla çökmesin
      _meshR[i] = _meshR[i].clamp(maxInward, maxOutward);
      _meshV[i] = _meshV[i].clamp(-_baseRadius * 2, _baseRadius * 2);
    }
  }

  void _spawnParticle(Offset pos, double angle, double intensity) {
    final speed = 100 + _rng.nextDouble() * 250 * intensity;
    final spread = (_rng.nextDouble() - 0.5) * 2.2;
    final colors = [
      _accent,
      Colors.white70,
      const Color(0xFF6FAAFF),
      const Color(0xFFBBDEFB),
      const Color(0xFF448AFF),
    ];
    _particles.add(_Particle(
      x: pos.dx, y: pos.dy,
      vx: math.cos(angle + spread) * speed,
      vy: math.sin(angle + spread) * speed - 70,
      life: 0.4 + _rng.nextDouble() * 0.8,
      size: 2.5 + _rng.nextDouble() * 7 * intensity,
      color: colors[_rng.nextInt(colors.length)],
    ));
  }

  double _angleDiff(double a, double b) {
    var d = a - b;
    while (d > math.pi) d -= 2 * math.pi;
    while (d < -math.pi) d += 2 * math.pi;
    return d;
  }

  // ════════════════════════════════════════════════════════════════
  //  TOUCH — Listener ile anında tepki
  // ════════════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent e) {
    _fingers[e.pointer] = e.localPosition;
    _fingerStarts[e.pointer] = e.localPosition;
    _fingerMoveDist[e.pointer] = 0;

    final dx = e.localPosition.dx - _ballCenter.dx;
    final dy = e.localPosition.dy - _ballCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // Tek parmak ve topun içindeyse → sürükleme başlat
    if (dist < _baseRadius * 1.3 && _fingers.length == 1) {
      _isDragging = true;
      _dragPointer = e.pointer;
      _dragOffset = Offset(dx, dy);
      _ballVelocity = Offset.zero;
    }
    if (dist < _baseRadius * 1.5) {
      HapticFeedback.mediumImpact();
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    final prev = _fingers[e.pointer];
    _fingers[e.pointer] = e.localPosition;

    // Hareket mesafesi takibi
    if (prev != null) {
      _fingerMoveDist[e.pointer] = (_fingerMoveDist[e.pointer] ?? 0) + (e.localPosition - prev).distance;
    }

    // İki parmak varsa sürüklemeyi iptal et, sıkma moduna geç
    if (_fingers.length >= 2 && _isDragging) {
      _isDragging = false;
      _dragPointer = null;
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    final wasDragPointer = _dragPointer == e.pointer;
    _fingers.remove(e.pointer);
    _fingerStarts.remove(e.pointer);
    _fingerMoveDist.remove(e.pointer);

    if (wasDragPointer) {
      _isDragging = false;
      _dragPointer = null;
      // Fırlatma hızı zaten _ballVelocity'de kayıtlı
    }

    if (_fingers.isEmpty) {
      _squeezeCount++;
      // Güçlü jelly bounce — bırakınca belirgin sallanma
      for (int i = 0; i < _N; i++) {
        _meshV[i] += (_rng.nextDouble() - 0.5) * _baseRadius * 0.8;
        // Sıkılmış noktalar ekstra geri sekmeli
        if (_meshR[i] < -5) _meshV[i] += -_meshR[i] * 3;
      }
      HapticFeedback.heavyImpact();
    }
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (_dragPointer == e.pointer) {
      _isDragging = false;
      _dragPointer = null;
    }
    _fingers.remove(e.pointer);
    _fingerStarts.remove(e.pointer);
    _fingerMoveDist.remove(e.pointer);
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    _screenSize = MediaQuery.of(context).size;
    final l = AppLocalizations.of(context);

    if (!_layoutDone) {
      _baseRadius = _screenSize.width * 0.32;
      _ballCenter = Offset(_screenSize.width / 2, _screenSize.height * 0.44);
      _layoutDone = true;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF03020A),
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Arka plan
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.3), radius: 1.4,
                  colors: [Color(0xFF0A1628), Color(0xFF050D1A), Color(0xFF03020A)],
                ),
              ),
            ),

            // Glow (sıkma yoğunluğuna göre)
            Positioned(
              left: _ballCenter.dx - _baseRadius * 2,
              top: _ballCenter.dy - _baseRadius * 2,
              child: Container(
                width: _baseRadius * 4, height: _baseRadius * 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _blue2.withValues(alpha: 0.05 + _currentPressure * 0.2),
                    Colors.transparent,
                  ]),
                ),
              ),
            ),

            // Top
            RepaintBoundary(
              child: CustomPaint(
                size: _screenSize,
                painter: _BallPainter(
                  center: _ballCenter,
                  baseRadius: _baseRadius,
                  meshR: _meshR,
                  faceEmotion: _faceEmotion,
                  wobble: _wobble,
                  particles: _particles,
                  decoIcons: _deco,
                  pressure: _currentPressure,
                  fingers: _fingers.values.toList(),
                ),
              ),
            ),

            // Parmak göstergeleri (dokunulan noktaları göster)
            ..._fingers.values.map((f) {
              final dx = f.dx - _ballCenter.dx;
              final dy = f.dy - _ballCenter.dy;
              final dist = math.sqrt(dx * dx + dy * dy);
              if (dist > _baseRadius * 1.5) return const SizedBox.shrink();
              return Positioned(
                left: f.dx - 20, top: f.dy - 20,
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
                  ),
                ),
              );
            }),

            // Üst bar
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(l?.menuStressBall.toUpperCase() ?? 'STRES TOPU',
                    style: const TextStyle(color: Colors.white, fontSize: 18,
                      fontWeight: FontWeight.w900, letterSpacing: 2)),
                  const Spacer(),
                  // Sıkma sayacı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _blue2.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Text('✊', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Text('$_squeezeCount',
                        style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ]),
              ),
            ),

            // Basınç göstergesi (sıkılırken görünür)
            if (_currentPressure > 0.1)
              Positioned(
                bottom: 100, left: 40, right: 40,
                child: Column(children: [
                  Text('${ (_currentPressure * 100).toInt() }%',
                    style: TextStyle(
                      color: Color.lerp(_accent, const Color(0xFFFF6B6B), _currentPressure)!.withValues(alpha: 0.6),
                      fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _currentPressure.clamp(0, 1),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(
                        Color.lerp(_accent, const Color(0xFFFF6B6B), _currentPressure)!.withValues(alpha: 0.5)),
                      minHeight: 4,
                    ),
                  ),
                ]),
              ),

            // Alt bilgi
            Positioned(
              bottom: 90, left: 0, right: 0,
              child: Column(children: [
                Text(l?.stressBallHint ?? 'Sık, Bırak, Rahatla',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25),
                    fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1)),
                const SizedBox(height: 8),
                Text('⚡ ${GameState.instance.formattedRpm} RPM',
                  style: TextStyle(color: _accent.withValues(alpha: 0.4),
                    fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
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
}

// ════════════════════════════════════════════════════════════════════
//  PAINTER
// ════════════════════════════════════════════════════════════════════

class _BallPainter extends CustomPainter {
  final Offset center;
  final double baseRadius;
  final List<double> meshR;
  final double faceEmotion;
  final double wobble;
  final List<_Particle> particles;
  final List<IconData> decoIcons;
  final double pressure;
  final List<Offset> fingers;

  _BallPainter({
    required this.center, required this.baseRadius, required this.meshR,
    required this.faceEmotion, required this.wobble, required this.particles,
    required this.decoIcons, required this.pressure, required this.fingers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawShadow(canvas);
    _drawBall(canvas);
    _drawDecoIcons(canvas);
    _drawBallText(canvas);
    _drawFace(canvas);
    _drawHighlight(canvas);
    _drawParticles(canvas);
  }

  void _drawShadow(Canvas canvas) {
    final w = baseRadius * (1.3 + pressure * 0.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + baseRadius * 0.95),
        width: w * 2, height: baseRadius * 0.25),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
    );
  }

  void _drawBall(Canvas canvas) {
    final path = _buildMeshPath();

    final gradient = ui.Gradient.radial(
      Offset(center.dx - baseRadius * 0.25, center.dy - baseRadius * 0.3),
      baseRadius * 2,
      [
        const Color(0xFF6FAAFF),
        const Color(0xFF4A90FF),
        const Color(0xFF2962FF),
        const Color(0xFF1545B0),
        const Color(0xFF0D3380),
      ],
      [0.0, 0.2, 0.45, 0.75, 1.0],
    );

    canvas.drawPath(path, Paint()..shader = gradient);
    canvas.drawPath(path, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF82B1FF).withValues(alpha: 0.12));
  }

  Path _buildMeshPath() {
    final n = meshR.length;
    final points = <Offset>[];
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2;
      final r = baseRadius + meshR[i];
      points.add(Offset(center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r));
    }

    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < n; i++) {
      final p0 = points[i];
      final p1 = points[(i + 1) % n];
      final p2 = points[(i + 2) % n];
      final prev = points[(i - 1 + n) % n];
      path.cubicTo(
        p0.dx + (p1.dx - prev.dx) / 4, p0.dy + (p1.dy - prev.dy) / 4,
        p1.dx - (p2.dx - p0.dx) / 4, p1.dy - (p2.dy - p0.dy) / 4,
        p1.dx, p1.dy,
      );
    }
    path.close();
    return path;
  }

  void _drawDecoIcons(Canvas canvas) {
    final n = decoIcons.length;
    for (int i = 0; i < n; i++) {
      final angle = (i / n) * math.pi * 2 + wobble * 0.08;
      final meshIdx = ((angle / (math.pi * 2)) * meshR.length).round() % meshR.length;
      final dist = baseRadius * 0.58 + meshR[meshIdx] * 0.6;
      final x = center.dx + math.cos(angle) * dist;
      final y = center.dy + math.sin(angle) * dist;

      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(decoIcons[i].codePoint),
          style: TextStyle(
            fontFamily: decoIcons[i].fontFamily,
            package: decoIcons[i].fontPackage,
            fontSize: baseRadius * 0.15,
            color: const Color(0xFFBBDEFB).withValues(alpha: 0.3),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  void _drawBallText(Canvas canvas) {
    // Ortadaki STRESS BALL yazısı (yüzün altında)
    final tp = TextPainter(
      text: TextSpan(
        text: 'SQUEEZE · RELAX',
        style: TextStyle(
          fontSize: baseRadius * 0.075,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.3),
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + baseRadius * 0.38));
  }

  void _drawFace(Canvas canvas) {
    final eyeY = center.dy - baseRadius * 0.08;
    final eyeSpacing = baseRadius * 0.2;
    final eyeSize = baseRadius * 0.06;
    final eyeScaleY = 1.0 - faceEmotion * 0.65;
    final eyeScaleX = 1.0 + faceEmotion * 0.35;

    // Sol göz
    _drawEye(canvas, Offset(center.dx - eyeSpacing, eyeY), eyeSize, eyeScaleX, eyeScaleY);
    // Sağ göz
    _drawEye(canvas, Offset(center.dx + eyeSpacing, eyeY), eyeSize, eyeScaleX, eyeScaleY);

    // Ağız
    final mouthY = center.dy + baseRadius * 0.17;
    final mouthW = baseRadius * 0.2;
    final mouthPath = Path();
    final mouthPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.65);

    if (faceEmotion < 0.3) {
      // Gülümseme
      mouthPath.moveTo(center.dx - mouthW, mouthY);
      mouthPath.quadraticBezierTo(center.dx, mouthY + baseRadius * 0.1, center.dx + mouthW, mouthY);
    } else if (faceEmotion < 0.7) {
      // Düz ağız
      mouthPath.moveTo(center.dx - mouthW * 0.6, mouthY);
      mouthPath.lineTo(center.dx + mouthW * 0.6, mouthY);
    } else {
      // Sıkışmış — ters gülümseme + dil
      mouthPath.moveTo(center.dx - mouthW * 0.7, mouthY);
      mouthPath.quadraticBezierTo(center.dx, mouthY - baseRadius * 0.06, center.dx + mouthW * 0.7, mouthY);
    }
    canvas.drawPath(mouthPath, mouthPaint);

    // Kızaran yanaklar
    if (faceEmotion > 0.25) {
      final a = ((faceEmotion - 0.25) * 0.5).clamp(0.0, 0.35);
      final cheek = Paint()
        ..color = const Color(0xFFFF6B6B).withValues(alpha: a)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(center.dx - eyeSpacing * 1.6, eyeY + baseRadius * 0.13), baseRadius * 0.07, cheek);
      canvas.drawCircle(Offset(center.dx + eyeSpacing * 1.6, eyeY + baseRadius * 0.13), baseRadius * 0.07, cheek);
    }

    // Ter damlaları (çok sıkılınca)
    if (faceEmotion > 0.6) {
      final sweatAlpha = ((faceEmotion - 0.6) * 2).clamp(0.0, 0.6);
      final sweatPaint = Paint()..color = const Color(0xFF82B1FF).withValues(alpha: sweatAlpha);
      canvas.drawCircle(
        Offset(center.dx + eyeSpacing * 1.8, eyeY - baseRadius * 0.06),
        baseRadius * 0.03, sweatPaint);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(center.dx + eyeSpacing * 1.8, eyeY + baseRadius * 0.01),
          width: baseRadius * 0.025, height: baseRadius * 0.04),
        sweatPaint);
    }
  }

  void _drawEye(Canvas canvas, Offset center, double size, double sx, double sy) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(sx, sy);
    // Beyaz
    canvas.drawCircle(Offset.zero, size, Paint()..color = Colors.white.withValues(alpha: 0.85));
    // Göz bebeği
    canvas.drawCircle(Offset.zero, size * 0.5, Paint()..color = const Color(0xFF1A237E));
    // Parlama
    canvas.drawCircle(Offset(size * 0.15, -size * 0.12), size * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.85));
    canvas.restore();
  }

  void _drawHighlight(Canvas canvas) {
    canvas.drawCircle(
      Offset(center.dx - baseRadius * 0.22, center.dy - baseRadius * 0.28),
      baseRadius * 0.4,
      Paint()..shader = ui.Gradient.radial(
        Offset(center.dx - baseRadius * 0.3, center.dy - baseRadius * 0.35),
        baseRadius * 0.5,
        [Colors.white.withValues(alpha: 0.18), Colors.transparent],
      ),
    );
    canvas.drawCircle(
      Offset(center.dx - baseRadius * 0.38, center.dy - baseRadius * 0.38),
      baseRadius * 0.1,
      Paint()..shader = ui.Gradient.radial(
        Offset(center.dx - baseRadius * 0.38, center.dy - baseRadius * 0.38),
        baseRadius * 0.12,
        [Colors.white.withValues(alpha: 0.3), Colors.transparent],
      ),
    );
  }

  void _drawParticles(Canvas canvas) {
    for (final p in particles) {
      final a = (p.life * 2).clamp(0.0, 1.0);
      final pos = Offset(p.x, p.y);
      final sz = p.size * a;
      // Glow
      canvas.drawCircle(pos, sz * 2.5, Paint()
        ..color = p.color.withValues(alpha: a * 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      // Core
      canvas.drawCircle(pos, sz, Paint()
        ..color = p.color.withValues(alpha: a * 0.8)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
      // Bright center
      canvas.drawCircle(pos, sz * 0.4, Paint()
        ..color = Colors.white.withValues(alpha: a * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _BallPainter old) => true;
}

class _Particle {
  double x, y, vx, vy, life, size;
  Color color;
  _Particle({required this.x, required this.y, required this.vx, required this.vy,
    required this.life, required this.size, required this.color});
}
