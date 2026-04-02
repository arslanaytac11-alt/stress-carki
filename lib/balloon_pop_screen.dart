import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_state.dart';
import 'sound_engine.dart';
import 'l10n/app_localizations.dart';

// ════════════════════════════════════════════════════════════════════
//  BALON PATLATMA MODU — Premium Efektlerle
// ════════════════════════════════════════════════════════════════════

enum BalloonType { normal, gold, ice }

class _Balloon {
  double x, y, vx, vy, radius;
  Color color;
  BalloonType type;
  double wobblePhase;
  double wobbleAmp;
  bool popped;
  double glow;

  _Balloon({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.radius, required this.color,
    this.type = BalloonType.normal,
    this.wobblePhase = 0, this.wobbleAmp = 0,
    this.popped = false, this.glow = 0,
  });
}

class _Particle {
  double x, y, vx, vy, radius, life, rotation, rotSpeed;
  Color color;
  _Particle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.radius, required this.color,
    this.life = 1.0, this.rotation = 0, this.rotSpeed = 0,
  });
}

class _Ring {
  double x, y, radius, maxRadius, life;
  Color color;
  _Ring({required this.x, required this.y, required this.color,
    this.radius = 0, this.maxRadius = 80, this.life = 1.0});
}

class _Confetti {
  double x, y, vx, vy, rotation, rotSpeed, life, width, height;
  Color color;
  _Confetti({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.color,
    this.rotation = 0, this.rotSpeed = 0, this.life = 1.0,
    this.width = 6, this.height = 10,
  });
}

class _ComboText {
  double x, y, scale, life;
  String text;
  Color color;
  _ComboText({required this.x, required this.y, required this.text,
    required this.color, this.scale = 0, this.life = 1.0});
}

// ── Ana Ekran ──
class BalloonPopScreen extends StatefulWidget {
  const BalloonPopScreen({super.key});
  @override
  State<BalloonPopScreen> createState() => _BalloonPopScreenState();
}

class _BalloonPopScreenState extends State<BalloonPopScreen>
    with TickerProviderStateMixin {

  late AnimationController _loop;
  final math.Random _rng = math.Random();

  // Oyun durumu
  final List<_Balloon> _balloons = [];
  final List<_Particle> _particles = [];
  final List<_Ring> _rings = [];
  final List<_Confetti> _confetti = [];
  final List<_ComboText> _comboTexts = [];

  int _score = 0;
  int _bestScore = 0;
  int _missed = 0;
  int _combo = 0;
  double _comboTimer = 0;
  double _shake = 0;
  double _shakeAngle = 0;
  double _spawnTimer = 0;
  double _spawnInterval = 1.2; // saniye
  double _gameTime = 0;
  double _slowMotion = 1.0; // 1.0 = normal, 0.4 = slow
  double _slowTimer = 0;
  bool _gameOver = false;
  bool _started = false;

  // Seviye sistemi
  int _level = 1;
  double _levelTimer = 0;
  double _levelFlash = 0; // seviye atlama efekti
  static const double _levelDuration = 30.0; // her 30 saniyede seviye atla

  Size _sz = Size.zero;

  static const int _maxMissed = 3;
  static const List<Color> _balloonColors = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFF45B7D1),
    Color(0xFFFFBE0B), Color(0xFFFB5607), Color(0xFF8338EC),
    Color(0xFF3A86FF), Color(0xFFFF006E), Color(0xFF06D6A0),
  ];

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadBest();
    _loop = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_tick)
      ..forward();
  }

  Future<void> _loadBest() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _bestScore = prefs.getInt('balloon_best') ?? 0);
  }

  Future<void> _saveBest() async {
    if (_score > _bestScore) {
      _bestScore = _score;
      final prefs = await SharedPreferences.getInstance();
      prefs.setInt('balloon_best', _bestScore);
    }
  }

  DateTime _lastTick = DateTime.now();
  void _tick() {
    if (!mounted || _gameOver || !_started) return;
    final now = DateTime.now();
    var dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;

    // Slow motion efekti
    if (_slowTimer > 0) {
      _slowTimer -= dt;
      _slowMotion = 0.35;
      if (_slowTimer <= 0) _slowMotion = 1.0;
    }
    dt *= _slowMotion;

    _gameTime += dt;
    _shake *= 0.88;

    // Combo timer
    if (_combo > 1) {
      _comboTimer -= dt;
      if (_comboTimer <= 0) _combo = 0;
    }

    // ── Seviye sistemi ──
    _levelTimer += dt;
    _levelFlash *= 0.92;
    if (_levelTimer >= _levelDuration) {
      _levelTimer = 0;
      _level++;
      _levelFlash = 1.0;
      SoundEngine.levelUp();
    }

    // ── Zorluk artışı — seviye bazlı ──
    _spawnInterval = (1.2 - (_level - 1) * 0.12).clamp(0.28, 1.2);

    // ── Balon spawn — seviyeye göre ──
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnTimer = _spawnInterval;
      _spawnBalloon();
      // Seviyeye göre ekstra balonlar
      if (_level >= 2 && _rng.nextDouble() < 0.3) _spawnBalloon();
      if (_level >= 3 && _rng.nextDouble() < 0.35) _spawnBalloon();
      if (_level >= 5 && _rng.nextDouble() < 0.25) _spawnBalloon();
    }

    // ── Balon fiziği ──
    final bsw = _sz.width;
    for (final b in _balloons) {
      if (b.popped) continue;
      b.y += b.vy * dt;
      b.x += b.vx * dt + math.sin(b.wobblePhase) * b.wobbleAmp * dt;
      b.wobblePhase += 2.5 * dt;
      b.glow = 0.3 + math.sin(_gameTime * 3 + b.wobblePhase) * 0.15;
      // Ekran sınırları — balonlar yandan çıkmasın
      if (b.x < b.radius) { b.x = b.radius; b.vx = b.vx.abs() * 0.5; }
      if (b.x > bsw - b.radius) { b.x = bsw - b.radius; b.vx = -b.vx.abs() * 0.5; }
    }

    // Kaçan balonları kontrol et
    final escaped = _balloons.where((b) => !b.popped && b.y < -b.radius * 2).toList();
    for (final b in escaped) {
      b.popped = true;
      _missed++;
      SoundEngine.balloonMiss();
      if (_missed >= _maxMissed) {
        _gameOver = true;
        _saveBest();
        SoundEngine.gameOver();
      }
    }

    // Ölü balonları temizle
    _balloons.removeWhere((b) => b.popped && b.y < -200);

    // ── Parçacık fiziği ──
    for (final p in _particles) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy += 600 * dt; // gravity
      p.life -= dt * 1.8;
      p.rotation += p.rotSpeed * dt;
      p.radius *= 0.995;
    }
    _particles.removeWhere((p) => p.life <= 0);

    // ── Halkalar ──
    for (final r in _rings) {
      r.radius += (r.maxRadius - r.radius) * 4 * dt;
      r.life -= dt * 2.5;
    }
    _rings.removeWhere((r) => r.life <= 0);

    // ── Konfeti ──
    for (final c in _confetti) {
      c.x += c.vx * dt;
      c.y += c.vy * dt;
      c.vy += 200 * dt;
      c.rotation += c.rotSpeed * dt;
      c.life -= dt * 0.7;
    }
    _confetti.removeWhere((c) => c.life <= 0);
    if (_confetti.length > 200) _confetti.removeRange(0, _confetti.length - 200);

    // ── Combo text ──
    for (final ct in _comboTexts) {
      ct.y -= 60 * dt;
      ct.scale = (ct.scale + 4 * dt).clamp(0, 1.5);
      ct.life -= dt * 1.2;
    }
    _comboTexts.removeWhere((ct) => ct.life <= 0);

    setState(() {});
  }

  void _spawnBalloon() {
    final sw = _sz.width;
    final sh = _sz.height;
    if (sw == 0) return;

    // Boyut çeşitliliği — seviyeye göre küçük balonlar da çıkar
    final sizeVar = _level >= 3 ? (_rng.nextDouble() < 0.3 ? -8.0 : 0.0) : 0.0;
    final radius = 28.0 + _rng.nextDouble() * 18 + sizeVar;
    final x = radius + _rng.nextDouble() * (sw - radius * 2);
    final baseSpeed = 50 + (_level - 1) * 15.0;
    final vy = -(baseSpeed + _rng.nextDouble() * 40);

    // Tip belirleme
    BalloonType type = BalloonType.normal;
    Color color;
    if (_rng.nextDouble() < 0.05) {
      type = BalloonType.gold;
      color = const Color(0xFFFFD700);
    } else if (_rng.nextDouble() < 0.08) {
      type = BalloonType.ice;
      color = const Color(0xFF88E0EF);
    } else {
      color = _balloonColors[_rng.nextInt(_balloonColors.length)];
    }

    _balloons.add(_Balloon(
      x: x, y: sh + radius,
      vx: (_rng.nextDouble() - 0.5) * 30,
      vy: vy,
      radius: radius, color: color, type: type,
      wobblePhase: _rng.nextDouble() * 6.28,
      wobbleAmp: 15 + _rng.nextDouble() * 25,
    ));
  }

  void _onTapDown(TapDownDetails d) {
    if (_gameOver) return;
    if (!_started) {
      setState(() {
        _started = true;
        _lastTick = DateTime.now();
      });
      return;
    }

    final tx = d.localPosition.dx;
    final ty = d.localPosition.dy;

    // En yakın balonu bul (üstteki öncelikli — son eklenen)
    _Balloon? hit;
    for (int i = _balloons.length - 1; i >= 0; i--) {
      final b = _balloons[i];
      if (b.popped) continue;
      final dist = math.sqrt(math.pow(b.x - tx, 2) + math.pow(b.y - ty, 2));
      if (dist < b.radius + 10) {
        hit = b;
        break;
      }
    }

    if (hit != null) {
      _popBalloon(hit);
    }
  }

  void _popBalloon(_Balloon b) {
    b.popped = true;
    SoundEngine.balloonPop(
      isGold: b.type == BalloonType.gold,
      isIce: b.type == BalloonType.ice,
      combo: _combo,
    );

    // Combo
    _combo++;
    _comboTimer = 1.5;
    final multiplier = _combo.clamp(1, 8);

    // Skor & RPM
    final baseRpm = b.type == BalloonType.gold ? 75.0 : 15.0;
    final rpm = baseRpm * multiplier;
    _score += (10 * multiplier);

    final newBadges = GameState.instance.addRpm(rpm);
    if (newBadges.isNotEmpty && mounted) {
      BadgeCelebration.show(context, newBadges.last);
    }

    // ── Patlama efektleri — çeşitli stiller ──
    _shake = 5 + multiplier * 2;
    _shakeAngle = _rng.nextDouble() * 6.28;

    // Patlama stili seç (her seferinde farklı)
    final popStyle = _rng.nextInt(4); // 0=dağılma, 1=spiral, 2=yıldız, 3=dalga

    // 1. Parçacıklar — stile göre
    final particleCount = b.type == BalloonType.gold ? 45 : 28;
    for (int i = 0; i < particleCount; i++) {
      double angle, speed;
      switch (popStyle) {
        case 1: // Spiral patlama
          angle = (i / particleCount) * 6.28 * 3 + _rng.nextDouble() * 0.5;
          speed = 100 + (i / particleCount) * 350;
          break;
        case 2: // Yıldız patlaması — 5 kol
          final arm = i % 5;
          final armAngle = arm * 6.28 / 5;
          angle = armAngle + (_rng.nextDouble() - 0.5) * 0.4;
          speed = 180 + _rng.nextDouble() * 300;
          break;
        case 3: // Dalga — yarım daire
          angle = -3.14 + (i / particleCount) * 3.14 + (_rng.nextDouble() - 0.5) * 0.3;
          speed = 150 + _rng.nextDouble() * 250;
          break;
        default: // Klasik dairesel dağılma
          angle = _rng.nextDouble() * 6.28;
          speed = 150 + _rng.nextDouble() * 350;
      }

      final pColor = b.type == BalloonType.gold
          ? Color.lerp(const Color(0xFFFFD700), const Color(0xFFFFF8E1), _rng.nextDouble())!
          : Color.lerp(b.color, Colors.white, _rng.nextDouble() * 0.5)!;

      // Balon parçaları — büyük düzensiz parçalar
      final isBigChunk = i < 6;
      _particles.add(_Particle(
        x: b.x + (_rng.nextDouble() - 0.5) * b.radius * 0.5,
        y: b.y + (_rng.nextDouble() - 0.5) * b.radius * 0.5,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 120,
        radius: isBigChunk ? (5 + _rng.nextDouble() * 6) : (1.5 + _rng.nextDouble() * 4),
        color: pColor,
        rotation: _rng.nextDouble() * 6.28,
        rotSpeed: (_rng.nextDouble() - 0.5) * 14,
      ));
    }

    // 2. Çoklu Işık halkası — iç + dış
    _rings.add(_Ring(
      x: b.x, y: b.y, color: b.color,
      maxRadius: b.type == BalloonType.gold ? 140 : 90,
    ));
    _rings.add(_Ring(
      x: b.x, y: b.y,
      color: Color.lerp(b.color, Colors.white, 0.5)!,
      maxRadius: b.type == BalloonType.gold ? 80 : 50,
    ));

    // 3. Altın balon — altın yağmuru
    if (b.type == BalloonType.gold) {
      _rings.add(_Ring(
        x: b.x, y: b.y, color: const Color(0xFFFFF8E1),
        maxRadius: 180,
      ));
      // Altın parıltı parçacıkları
      for (int i = 0; i < 20; i++) {
        final a = _rng.nextDouble() * 6.28;
        _particles.add(_Particle(
          x: b.x, y: b.y,
          vx: math.cos(a) * (50 + _rng.nextDouble() * 100),
          vy: -80 - _rng.nextDouble() * 150,
          radius: 1.5 + _rng.nextDouble() * 2,
          color: Color.lerp(const Color(0xFFFFD700), Colors.white, _rng.nextDouble() * 0.7)!,
          life: 1.5,
        ));
      }
    }

    // 4. Buz balonu slow-motion + kristal efekti
    if (b.type == BalloonType.ice) {
      _slowTimer = 2.5;
      for (int i = 0; i < 20; i++) {
        final angle = _rng.nextDouble() * 6.28;
        final spd = 40 + _rng.nextDouble() * 100;
        _particles.add(_Particle(
          x: b.x, y: b.y,
          vx: math.cos(angle) * spd,
          vy: math.sin(angle) * spd - 30,
          radius: 2 + _rng.nextDouble() * 4,
          color: Color.lerp(const Color(0xFF88E0EF), Colors.white, _rng.nextDouble())!,
          life: 2.5,
          rotSpeed: (_rng.nextDouble() - 0.5) * 6,
        ));
      }
      // Buz halkası
      _rings.add(_Ring(
        x: b.x, y: b.y, color: const Color(0xFF88E0EF),
        maxRadius: 160,
      ));
    }

    // 5. Combo text — daha dramatik
    if (multiplier >= 2) {
      _comboTexts.add(_ComboText(
        x: b.x, y: b.y - 50,
        text: multiplier >= 5 ? 'x$multiplier!!!' : multiplier >= 3 ? 'x$multiplier!!' : 'x$multiplier!',
        color: multiplier >= 8
            ? const Color(0xFFFF00FF)
            : multiplier >= 5
                ? const Color(0xFFFFD700)
                : multiplier >= 3
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF4ECDC4),
      ));
    }

    // 6. Konfeti (combo >= 3) — daha yoğun
    if (multiplier >= 3) {
      final confettiCount = 15 + multiplier * 4;
      for (int i = 0; i < confettiCount; i++) {
        _confetti.add(_Confetti(
          x: b.x + (_rng.nextDouble() - 0.5) * 100,
          y: b.y - _rng.nextDouble() * 60,
          vx: (_rng.nextDouble() - 0.5) * 150,
          vy: -50 + _rng.nextDouble() * 100,
          color: _balloonColors[_rng.nextInt(_balloonColors.length)],
          rotation: _rng.nextDouble() * 6.28,
          rotSpeed: (_rng.nextDouble() - 0.5) * 10,
          width: 3 + _rng.nextDouble() * 6,
          height: 6 + _rng.nextDouble() * 8,
        ));
      }
    }

    // 7. Ekstra: combo >= 5 ekran flaş
    if (multiplier >= 5) {
      _shake = 12 + multiplier * 2;
    }
  }

  void _restart() {
    setState(() {
      _balloons.clear();
      _particles.clear();
      _rings.clear();
      _confetti.clear();
      _comboTexts.clear();
      _score = 0;
      _missed = 0;
      _combo = 0;
      _comboTimer = 0;
      _spawnTimer = 0;
      _spawnInterval = 1.2;
      _gameTime = 0;
      _slowMotion = 1.0;
      _slowTimer = 0;
      _gameOver = false;
      _started = false;
      _shake = 0;
      _level = 1;
      _levelTimer = 0;
      _levelFlash = 0;
      _lastTick = DateTime.now();
    });
  }

  @override
  void dispose() {
    _loop.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _sz = MediaQuery.of(context).size;
    final l = AppLocalizations.of(context);
    final shakeX = math.cos(_shakeAngle) * _shake;
    final shakeY = math.sin(_shakeAngle) * _shake;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B2E),
      body: GestureDetector(
        onTapDown: _onTapDown,
        child: Transform.translate(
          offset: Offset(shakeX, shakeY),
          child: Stack(
            children: [
              // ── Arka plan ──
              RepaintBoundary(
                child: CustomPaint(size: _sz, painter: const _BalloonBGPainter()),
              ),

              // ── Oyun katmanı ──
              RepaintBoundary(
                child: CustomPaint(
                  size: _sz,
                  painter: _BalloonGamePainter(
                    balloons: _balloons,
                    particles: _particles,
                    rings: _rings,
                    confetti: _confetti,
                    comboTexts: _comboTexts,
                    slowMotion: _slowMotion < 1.0,
                  ),
                ),
              ),

              // ── UI Overlay ──
              SafeArea(
                child: Stack(
                  children: [
                    // Sol üst — Skor
                    Positioned(
                      left: 16, top: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 20),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$_score',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 32,
                                fontWeight: FontWeight.w900, letterSpacing: 2,
                              ),
                            ),
                          ]),
                          if (_combo >= 2)
                            Container(
                              margin: const EdgeInsets.only(left: 32, top: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  _combo >= 5
                                      ? const Color(0xFFFFD700)
                                      : _combo >= 3
                                          ? const Color(0xFFFF6B6B)
                                          : const Color(0xFF4ECDC4),
                                  Colors.transparent,
                                ]),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${l?.balloonCombo ?? "Combo"} x$_combo',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Sağ üst — Seviye + Kalpler
                    Positioned(
                      right: 16, top: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Seviye göstergesi
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _levelFlash > 0.1
                                  ? const Color(0xFFFFD700).withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _levelFlash > 0.1
                                    ? const Color(0xFFFFD700).withValues(alpha: 0.5)
                                    : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Text(
                              'LV $_level',
                              style: TextStyle(
                                color: _levelFlash > 0.1 ? const Color(0xFFFFD700) : Colors.white70,
                                fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Seviye progress bar
                          SizedBox(
                            width: 60,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: (_levelTimer / _levelDuration).clamp(0, 1),
                                minHeight: 3,
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                valueColor: AlwaysStoppedAnimation(
                                  Color.lerp(const Color(0xFF4ECDC4), const Color(0xFFFFD700),
                                      (_levelTimer / _levelDuration).clamp(0, 1))!,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Best score
                          Text(
                            '${l?.balloonBest ?? "Best"}: $_bestScore',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11, fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Kalpler
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(_maxMissed, (i) => Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: Icon(
                                i < (_maxMissed - _missed)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: i < (_maxMissed - _missed)
                                    ? const Color(0xFFFF6B6B)
                                    : Colors.white24,
                                size: 16,
                              ),
                            )),
                          ),
                        ],
                      ),
                    ),

                    // ── Slow motion göstergesi ──
                    if (_slowMotion < 1.0)
                      Positioned(
                        left: 0, right: 0, top: _sz.height * 0.12,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF88E0EF).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF88E0EF).withValues(alpha: 0.4)),
                            ),
                            child: const Text('❄️ SLOW MOTION ❄️', style: TextStyle(
                              color: Color(0xFF88E0EF), fontSize: 16,
                              fontWeight: FontWeight.w900, letterSpacing: 3,
                            )),
                          ),
                        ),
                      ),

                    // ── Başlangıç ekranı ──
                    if (!_started && !_gameOver)
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🎈', style: TextStyle(fontSize: 72)),
                            const SizedBox(height: 16),
                            Text(
                              l?.menuBalloon.toUpperCase() ?? 'BALON PATLATMA',
                              style: const TextStyle(
                                color: Colors.white, fontSize: 28,
                                fontWeight: FontWeight.w900, letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              l?.balloonTapToStart ?? 'Başlamak için dokun!',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Legend
                            _legendItem('🎈', l?.balloonNormal ?? 'Normal', '+15 RPM'),
                            _legendItem('✨', l?.balloonGold ?? 'Altın', '+75 RPM x5'),
                            _legendItem('❄️', l?.balloonIce ?? 'Buz', 'Slow Motion'),
                          ],
                        ),
                      ),

                    // ── Game Over ──
                    if (_gameOver)
                      Center(
                        child: Container(
                          margin: const EdgeInsets.all(32),
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B0B2E).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFFF6B6B).withValues(alpha: 0.3), width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                                blurRadius: 40,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l?.balloonGameOver ?? 'OYUN BİTTİ',
                                style: const TextStyle(
                                  color: Color(0xFFFF6B6B), fontSize: 24,
                                  fontWeight: FontWeight.w900, letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                '$_score',
                                style: const TextStyle(
                                  color: Colors.white, fontSize: 52,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                l?.balloonScore ?? 'Skor',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'LEVEL $_level',
                                  style: const TextStyle(
                                    color: Colors.white54, fontSize: 13,
                                    fontWeight: FontWeight.w700, letterSpacing: 2,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_score >= _bestScore)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(l?.balloonNewRecord ?? '🏆 NEW RECORD!', style: const TextStyle(
                                    color: Color(0xFFFFD700), fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  )),
                                ),
                              const SizedBox(height: 24),
                              GestureDetector(
                                onTap: _restart,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF4ECDC4), Color(0xFF45B7D1)],
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4ECDC4).withValues(alpha: 0.3),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    l?.balloonRestart ?? 'TEKRAR OYNA',
                                    style: const TextStyle(
                                      color: Colors.white, fontSize: 16,
                                      fontWeight: FontWeight.w900, letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value, style: const TextStyle(
              color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700,
            )),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PAINTERS
// ════════════════════════════════════════════════════════════════════

class _BalloonBGPainter extends CustomPainter {
  const _BalloonBGPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Gece gökyüzü gradient
    final bgPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero, Offset(0, size.height),
        [
          const Color(0xFF0B0B2E),
          const Color(0xFF1A1A4E),
          const Color(0xFF2D1B69),
          const Color(0xFF1A1A4E),
          const Color(0xFF0B0B2E),
        ],
        [0.0, 0.25, 0.5, 0.75, 1.0],
      );
    canvas.drawRect(Offset.zero & size, bgPaint);

    // Yıldızlar
    final starPaint = Paint()..color = Colors.white;
    final rng = math.Random(42);
    for (int i = 0; i < 150; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final r = 0.3 + rng.nextDouble() * 1.2;
      final alpha = 0.2 + rng.nextDouble() * 0.6;
      starPaint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), r, starPaint);
    }

    // Hafif nebula
    final nebPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    nebPaint.color = const Color(0xFF8338EC).withValues(alpha: 0.04);
    canvas.drawCircle(Offset(size.width * 0.3, size.height * 0.2), 120, nebPaint);
    nebPaint.color = const Color(0xFF3A86FF).withValues(alpha: 0.03);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.6), 100, nebPaint);
  }

  @override
  bool shouldRepaint(_BalloonBGPainter old) => false;
}

class _BalloonGamePainter extends CustomPainter {
  final List<_Balloon> balloons;
  final List<_Particle> particles;
  final List<_Ring> rings;
  final List<_Confetti> confetti;
  final List<_ComboText> comboTexts;
  final bool slowMotion;

  _BalloonGamePainter({
    required this.balloons, required this.particles,
    required this.rings, required this.confetti,
    required this.comboTexts, required this.slowMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Işık halkaları ──
    for (final r in rings) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * r.life
        ..color = r.color.withValues(alpha: r.life * 0.6)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * (1 - r.life) + 2);
      canvas.drawCircle(Offset(r.x, r.y), r.radius, paint);
    }

    // ── Balonlar ──
    for (final b in balloons) {
      if (b.popped) continue;

      // Glow
      final glowPaint = Paint()
        ..color = b.color.withValues(alpha: b.glow * 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
      canvas.drawCircle(Offset(b.x, b.y), b.radius + 12, glowPaint);

      // Balon gövdesi
      final bodyPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(b.x - b.radius * 0.3, b.y - b.radius * 0.3),
          b.radius * 1.5,
          [
            Color.lerp(b.color, Colors.white, 0.4)!,
            b.color,
            Color.lerp(b.color, Colors.black, 0.3)!,
          ],
          [0.0, 0.5, 1.0],
        );
      canvas.drawCircle(Offset(b.x, b.y), b.radius, bodyPaint);

      // Parlama highlight
      final hlPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.35);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(b.x - b.radius * 0.25, b.y - b.radius * 0.3),
          width: b.radius * 0.5, height: b.radius * 0.3,
        ),
        hlPaint,
      );

      // İp
      final ropePaint = Paint()
        ..color = b.color.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final ropePath = Path()
        ..moveTo(b.x, b.y + b.radius)
        ..cubicTo(
          b.x + 5, b.y + b.radius + 15,
          b.x - 5, b.y + b.radius + 30,
          b.x + 3, b.y + b.radius + 40,
        );
      canvas.drawPath(ropePath, ropePaint);

      // Altın balon sparkle
      if (b.type == BalloonType.gold) {
        final sparkPaint = Paint()
          ..color = const Color(0xFFFFF8E1).withValues(alpha: 0.7 + b.glow * 0.3);
        for (int i = 0; i < 4; i++) {
          final a = b.wobblePhase + i * 1.57;
          final r = b.radius * 0.7;
          canvas.drawCircle(
            Offset(b.x + math.cos(a) * r, b.y + math.sin(a) * r),
            2, sparkPaint,
          );
        }
      }

      // Buz balonu kristal efekti
      if (b.type == BalloonType.ice) {
        final icePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.15)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        for (int i = 0; i < 3; i++) {
          final a = b.wobblePhase + i * 2.09;
          final cx = b.x + math.cos(a) * b.radius * 0.4;
          final cy = b.y + math.sin(a) * b.radius * 0.4;
          canvas.drawLine(
            Offset(cx - 5, cy), Offset(cx + 5, cy), icePaint,
          );
          canvas.drawLine(
            Offset(cx, cy - 5), Offset(cx, cy + 5), icePaint,
          );
        }
      }
    }

    // ── Parçacıklar ──
    for (final p in particles) {
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.life.clamp(0, 1));
      canvas.drawCircle(Offset.zero, p.radius * p.life.clamp(0.3, 1), paint);
      canvas.restore();
    }

    // ── Konfeti ──
    for (final c in confetti) {
      canvas.save();
      canvas.translate(c.x, c.y);
      canvas.rotate(c.rotation);
      final paint = Paint()
        ..color = c.color.withValues(alpha: c.life.clamp(0, 1));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: c.width, height: c.height),
        paint,
      );
      canvas.restore();
    }

    // ── Combo text ──
    for (final ct in comboTexts) {
      final tp = TextPainter(
        text: TextSpan(
          text: ct.text,
          style: TextStyle(
            color: ct.color.withValues(alpha: ct.life.clamp(0, 1)),
            fontSize: 28 * ct.scale.clamp(0.5, 1.3),
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [
              Shadow(
                color: ct.color.withValues(alpha: ct.life * 0.5),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(ct.x - tp.width / 2, ct.y - tp.height / 2));
    }

    // ── Slow motion overlay ──
    if (slowMotion) {
      final overlayPaint = Paint()
        ..color = const Color(0xFF88E0EF).withValues(alpha: 0.05);
      canvas.drawRect(Offset.zero & size, overlayPaint);
    }
  }

  @override
  bool shouldRepaint(_BalloonGamePainter old) => true;
}
