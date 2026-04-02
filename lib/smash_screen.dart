import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'spinner_painter.dart';
import 'spinner_collection.dart';
import 'space_background_painter.dart';
import 'collection_screen.dart';
import 'game_state.dart';
import 'l10n/app_localizations.dart';

/// Parçalama Modu — Gerçek spinner görseli, kademeli hasar, uzayda süzülen parçalar.
/// Vurdukça kollar tek tek kopuyor, parçalar uzayda sürüklenebilir.
class SmashScreen extends StatefulWidget {
  final SpinnerModel spinnerModel;
  const SmashScreen({super.key, required this.spinnerModel});

  @override
  State<SmashScreen> createState() => _SmashScreenState();
}

class _SmashScreenState extends State<SmashScreen>
    with TickerProviderStateMixin {
  late AnimationController _gameLoop;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  late SpinnerModel _activeSpinner;

  // ── Spinner durumu ──
  double _spinAngle = 0.0;
  double _spinVelocity = 2.0;
  double _shake = 0.0;          // vuruş sarsıntısı
  int _health = _maxHealth;     // kalan can
  static const int _maxHealth = 8; // 8 kol = 8 vuruş
  final List<bool> _armAlive = List.filled(8, true);

  // ── Kopan parçalar (her kol bir parça) ──
  final List<_ArmShard> _armShards = [];

  // ── Küçük kırıntılar ──
  final List<_Debris> _debris = [];

  // ── Skor ──
  int _totalHits = 0;

  // ── Parça sürükleme ──
  int? _dragShardIdx;
  Offset _dragOffset = Offset.zero;

  final math.Random _rng = math.Random();

  // Spinner merkezi — cache to avoid per-frame MediaQuery lookup
  Size _screenSize = Size.zero;
  double get _cx => _screenSize.width / 2;
  double get _cy => _screenSize.height * 0.40;

  @override
  void initState() {
    super.initState();
    _activeSpinner = widget.spinnerModel;
    _gameLoop = AnimationController(
      vsync: this, duration: const Duration(days: 1),
    )..addListener(_tick);

    _glowCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );

    _gameLoop.forward();
  }

  DateTime _lastTick = DateTime.now();
  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;

    // ── Spinner dönüşü ──
    _spinAngle += _spinVelocity * dt;
    _shake *= 0.88; // sarsıntı azalır

    // ── Kopan kollar fiziği ──
    final sw = _screenSize.width;
    final sh = _screenSize.height;
    for (final s in _armShards) {
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.angle += s.rotSpeed * dt;
      s.vx *= 0.998;
      s.vy *= 0.998;
      if (s.x < 20) { s.x = 20; s.vx = s.vx.abs() * 0.6; }
      if (s.x > sw - 20) { s.x = sw - 20; s.vx = -s.vx.abs() * 0.6; }
      if (s.y < 20) { s.y = 20; s.vy = s.vy.abs() * 0.6; }
      if (s.y > sh - 20) { s.y = sh - 20; s.vy = -s.vy.abs() * 0.6; }
    }

    // ── Kırıntılar — cap at 300 ──
    if (_debris.length > 300) _debris.removeRange(0, _debris.length - 300);
    for (final d in _debris) {
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.rotation += d.rotSpeed * dt;
      d.vx *= 0.997;
      d.vy *= 0.997;
      if (d.x < 0) { d.x = 0; d.vx = d.vx.abs() * 0.5; }
      if (d.x > sw) { d.x = sw; d.vx = -d.vx.abs() * 0.5; }
      if (d.y < 0) { d.y = 0; d.vy = d.vy.abs() * 0.5; }
      if (d.y > sh) { d.y = sh; d.vy = -d.vy.abs() * 0.5; }
    }

    setState(() {});
  }

  void _resetSpinner() {
    setState(() {
      _armShards.clear();
      _debris.clear();
      _health = _maxHealth;
      for (int i = 0; i < 8; i++) _armAlive[i] = true;
      _spinVelocity = 2.0;
      _totalHits = 0;
    });
  }

  void _openSpinnerPicker() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => CollectionScreen(
        allTimeMaxRpm: 999, // parçala modunda hepsi açık
        selectedId: _activeSpinner.id,
        onSelect: (s) {
          setState(() {
            _activeSpinner = s;
            // Yeni çarkla sıfırla
            _armShards.clear();
            _debris.clear();
            _health = _maxHealth;
            for (int i = 0; i < 8; i++) _armAlive[i] = true;
            _spinVelocity = 2.0;
          });
        },
      ),
    ));
  }

  // ── Vuruş ──
  void _onTapDown(TapDownDetails details) {
    final tapX = details.globalPosition.dx;
    final tapY = details.globalPosition.dy;

    // Önce parçalara dokunma kontrolü
    for (int i = _armShards.length - 1; i >= 0; i--) {
      final s = _armShards[i];
      final dist = math.sqrt((tapX - s.x) * (tapX - s.x) + (tapY - s.y) * (tapY - s.y));
      if (dist < 50) {
        // Parçayı it
        final angle = math.atan2(tapY - s.y, tapX - s.x);
        s.vx -= math.cos(angle) * 120;
        s.vy -= math.sin(angle) * 120;
        s.rotSpeed += (_rng.nextDouble() - 0.5) * 6;
        HapticFeedback.lightImpact();
        // Kırıntı saç
        _spawnDebris(tapX, tapY, 4, s.color);
        // Parça fırlatma RPM
        final bs = GameState.instance.addRpm(5);
        if (bs.isNotEmpty && mounted) BadgeCelebration.show(context, bs.last);
        return;
      }
    }

    // Kırıntılara dokunma — it
    for (final d in _debris) {
      final dist2 = math.sqrt((tapX - d.x) * (tapX - d.x) + (tapY - d.y) * (tapY - d.y));
      if (dist2 < 30) {
        final angle = math.atan2(tapY - d.y, tapX - d.x);
        d.vx -= math.cos(angle) * 80;
        d.vy -= math.sin(angle) * 80;
        d.rotSpeed += (_rng.nextDouble() - 0.5) * 8;
      }
    }

    if (_health <= 0) return; // tamamen kırık

    // Spinner'a vuruş mesafesi
    final dist = math.sqrt((tapX - _cx) * (tapX - _cx) + (tapY - _cy) * (tapY - _cy));
    if (dist > 160) return;

    // En yakın canlı kolu bul
    int? hitArm;
    double bestDist = double.infinity;
    const R = 120.0; // spinner radius
    for (int i = 0; i < 8; i++) {
      if (!_armAlive[i]) continue;
      final armAngle = _spinAngle + (2 * math.pi / 8) * i;
      final armX = _cx + math.cos(armAngle) * R * 0.6;
      final armY = _cy + math.sin(armAngle) * R * 0.6;
      final d = math.sqrt((tapX - armX) * (tapX - armX) + (tapY - armY) * (tapY - armY));
      if (d < bestDist) {
        bestDist = d;
        hitArm = i;
      }
    }

    if (hitArm == null) return;

    // KOL KOP!
    HapticFeedback.heavyImpact();
    _armAlive[hitArm] = false;
    _health--;
    _totalHits++;
    // Global RPM
    final rpmReward = _health <= 0 ? 200.0 : 40.0;
    final newBadges = GameState.instance.addRpm(rpmReward);
    if (newBadges.isNotEmpty && mounted) BadgeCelebration.show(context, newBadges.last);
    _shake = 8.0 + (8 - _health) * 2.0; // hasar arttıkça daha çok sarsılır

    // Koparılan kolun uçuş yönü
    final armAngle = _spinAngle + (2 * math.pi / 8) * hitArm;
    final colors = _activeSpinner.skin.colors;
    final shardColor = Color.lerp(colors[0], colors[1], hitArm / 8.0)!;

    // Kol → 6-10 orta parça + 25-40 küçük kırıntı
    final baseX = _cx + math.cos(armAngle) * R * 0.5;
    final baseY = _cy + math.sin(armAngle) * R * 0.5;

    // Orta parçalar (kol parçaları) — daha fazla, daha küçük
    final midCount = 6 + _rng.nextInt(5);
    for (int j = 0; j < midCount; j++) {
      final spread = (_rng.nextDouble() - 0.5) * 1.0;
      final dist2 = 0.2 + _rng.nextDouble() * 0.6;
      _armShards.add(_ArmShard(
        x: _cx + math.cos(armAngle + spread) * R * dist2,
        y: _cy + math.sin(armAngle + spread) * R * dist2,
        vx: math.cos(armAngle + spread) * (40 + _rng.nextDouble() * 120) + (tapX - _cx) * -0.5,
        vy: math.sin(armAngle + spread) * (40 + _rng.nextDouble() * 120) + (tapY - _cy) * -0.5,
        angle: armAngle + _rng.nextDouble() * 2,
        rotSpeed: (_rng.nextDouble() - 0.5) * 10.0,
        armIndex: hitArm,
        color: shardColor,
        size: 0.25 + _rng.nextDouble() * 0.45, // daha küçük parçalar
      ));
    }

    // Küçük kırıntılar — çok daha fazla
    _spawnDebris(baseX, baseY, 25 + _rng.nextInt(16), shardColor);

    // Hız değişimi — hasar arttıkça dengesiz dönüş
    _spinVelocity += (_rng.nextDouble() - 0.5) * 2.0;

    // Tam parçalanma — spinner durur, parçalar kalır
    if (_health <= 0) {
      _spinVelocity = 0;
      _spawnDebris(_cx, _cy, 25, colors[0]);
      HapticFeedback.heavyImpact();
    }
  }

  void _spawnDebris(double ox, double oy, int count, Color color) {
    for (int i = 0; i < count; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 30 + _rng.nextDouble() * 120;
      _debris.add(_Debris(
        x: ox + (_rng.nextDouble() - 0.5) * 10,
        y: oy + (_rng.nextDouble() - 0.5) * 10,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        rotation: _rng.nextDouble() * 6.28,
        rotSpeed: (_rng.nextDouble() - 0.5) * 10,
        size: 2 + _rng.nextDouble() * 5,
        life: 2.0 + _rng.nextDouble() * 2.0,
        color: Color.lerp(color, Colors.white, _rng.nextDouble() * 0.3)!,
        type: _rng.nextInt(3),
      ));
    }
  }

  // ── Parça sürükleme ──
  void _onPanStart(DragStartDetails details) {
    final tx = details.globalPosition.dx;
    final ty = details.globalPosition.dy;
    for (int i = _armShards.length - 1; i >= 0; i--) {
      final s = _armShards[i];
      final dist = math.sqrt((tx - s.x) * (tx - s.x) + (ty - s.y) * (ty - s.y));
      if (dist < 60) {
        _dragShardIdx = i;
        _dragOffset = Offset(s.x - tx, s.y - ty);
        s.vx = 0; s.vy = 0; // dur
        return;
      }
    }
    _dragShardIdx = null;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragShardIdx == null || _dragShardIdx! >= _armShards.length) return;
    final s = _armShards[_dragShardIdx!];
    s.x = details.globalPosition.dx + _dragOffset.dx;
    s.y = details.globalPosition.dy + _dragOffset.dy;
  }

  void _onPanEnd(DragEndDetails details) {
    if (_dragShardIdx != null && _dragShardIdx! < _armShards.length) {
      final s = _armShards[_dragShardIdx!];
      s.vx = details.velocity.pixelsPerSecond.dx * 0.3;
      s.vy = details.velocity.pixelsPerSecond.dy * 0.3;
    }
    _dragShardIdx = null;
  }

  @override
  void dispose() {
    GameState.instance.save();
    _gameLoop.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _activeSpinner.skin.colors;
    _screenSize = MediaQuery.of(context).size;
    final screenSize = _screenSize;

    return Scaffold(
      backgroundColor: const Color(0xFF03020F),
      body: GestureDetector(
        onTapDown: _onTapDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
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
            // Tint
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center, radius: 0.6,
                    colors: [colors[0].withValues(alpha: 0.05), Colors.transparent],
                  ),
                ),
              ),
            ),
            // ── Kırıntılar ──
            CustomPaint(
              size: screenSize,
              painter: _DebrisPainter(_debris),
            ),
            // ── Kopan kol parçaları ──
            CustomPaint(
              size: screenSize,
              painter: _ArmShardPainter(_armShards, colors),
            ),
            // ── Spinner (hasarlı) ──
            if (_health > 0)
              AnimatedBuilder(
                animation: _glowCtrl,
                builder: (context, _) {
                  final shakeX = _shake * math.sin(_spinAngle * 13);
                  final shakeY = _shake * math.cos(_spinAngle * 17);
                  return Positioned(
                    left: _cx - 130 + shakeX,
                    top: _cy - 130 + shakeY,
                    child: CustomPaint(
                      size: const Size(260, 260),
                      painter: _DamagedSpinnerPainter(
                        angle: _spinAngle,
                        armAlive: List.from(_armAlive),
                        health: _health,
                        maxHealth: _maxHealth,
                        glowIntensity: _glowAnim.value,
                        primaryColor: colors[0],
                        secondaryColor: colors[1],
                      ),
                    ),
                  );
                },
              ),
            // ── Can barı ──
            Positioned(
              left: _cx - 80, top: _cy + 145, width: 160,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _health / _maxHealth,
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _health > 4 ? const Color(0xFF4CAF50)
                            : _health > 2 ? const Color(0xFFFF9800)
                            : const Color(0xFFFF3D00),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('$_health / $_maxHealth', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 10,
                    fontWeight: FontWeight.bold,
                  )),
                ],
              ),
            ),
            // ── İpucu ──
            if (_totalHits == 0)
              Positioned(
                left: 0, right: 0, top: _cy + 180,
                child: const Text('👆 Kollara dokun, kopar!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white30, fontSize: 14, letterSpacing: 1)),
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
                    Text(AppLocalizations.of(context)!.smashTitle, style: TextStyle(
                      foreground: Paint()..shader = const LinearGradient(
                        colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                      ).createShader(const Rect.fromLTWH(0, 0, 120, 25)),
                      fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3,
                    )),
                    const Spacer(),
                    GestureDetector(
                      onTap: _openSpinnerPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _activeSpinner.skin.colors
                                .map((c) => c.withValues(alpha: 0.25)).toList(),
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _activeSpinner.skin.colors[0].withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.catching_pokemon,
                                color: _activeSpinner.skin.colors[0], size: 16),
                            const SizedBox(width: 6),
                            Text(_activeSpinner.name, style: const TextStyle(
                              color: Colors.white, fontSize: 11,
                              fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ── Alt: parça sayısı + sıfırla butonu ──
            Positioned(
              left: 16, right: 16, bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Parça bilgisi
                  Text('${_armShards.length + _debris.length} parça',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12, letterSpacing: 1)),
                  const SizedBox(height: 10),
                  // Sıfırla butonu
                  GestureDetector(
                    onTap: _resetSpinner,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B6B).withValues(alpha: 0.3),
                            blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.smashReset, style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.w800, letterSpacing: 1)),
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
    );
  }

}

// ══════════════════════════════════════════════
//  Hasarlı Spinner Painter — SpinnerPainter'ın aynısı ama kollar eksik
// ══════════════════════════════════════════════
class _DamagedSpinnerPainter extends CustomPainter {
  final double angle;
  final List<bool> armAlive;
  final int health, maxHealth;
  final double glowIntensity;
  final Color primaryColor, secondaryColor;

  _DamagedSpinnerPainter({
    required this.angle, required this.armAlive,
    required this.health, required this.maxHealth,
    required this.glowIntensity,
    required this.primaryColor, required this.secondaryColor,
  });

  Color get _speedColor => primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final R = size.width / 2 * 0.90;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Hasar kırmızı glow
    if (health < maxHealth) {
      final dmg = 1.0 - health / maxHealth;
      canvas.drawCircle(Offset.zero, R,
        Paint()
          ..color = Colors.red.withValues(alpha: 0.08 * dmg)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 25),
      );
    }

    // Kollar — sadece hayatta olanlar
    const numArms = 8;
    final outerR = R * 0.72;
    final bearingR = R * 0.115;

    for (int i = 0; i < numArms; i++) {
      if (!armAlive[i]) continue; // kopmuş kol çizilmez

      canvas.save();
      canvas.rotate((2 * math.pi / numArms) * i);

      final armColor = Color.lerp(primaryColor, secondaryColor, i / numArms)!;
      _drawArm(canvas, R, outerR, bearingR, armColor);

      canvas.restore();
    }

    // Kopma izleri (kırık kol yerlerinde kıvılcım)
    for (int i = 0; i < numArms; i++) {
      if (armAlive[i]) continue;
      final a = (2 * math.pi / numArms) * i;
      final bx = math.cos(a) * R * 0.22;
      final by = math.sin(a) * R * 0.22;
      // Kırmızı kıvılcım
      canvas.drawCircle(Offset(bx, by), 4,
        Paint()
          ..color = Colors.orange.withValues(alpha: 0.5 * glowIntensity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }

    // Merkez hub
    _drawCenterHub(canvas, R);
    canvas.restore();
  }

  void _drawArm(Canvas canvas, double R, double outerR, double bearingR, Color color) {
    final innerR = R * 0.19;
    const sweep = 0.50;

    final path = Path();
    path.moveTo(innerR * math.cos(-sweep * 0.45), innerR * math.sin(-sweep * 0.45));
    path.cubicTo(innerR * 1.8, -R * 0.08, outerR * 0.50, -R * 0.28, outerR * 0.82, -R * 0.22);
    final bx = outerR * math.cos(sweep * 0.20);
    final by = outerR * math.sin(-sweep * 0.30);
    path.arcTo(
      Rect.fromCircle(center: Offset(bx, by), radius: bearingR),
      math.atan2(-R * 0.22 - by, outerR * 0.82 - bx) - 0.1,
      math.pi * 1.25, false,
    );
    path.cubicTo(outerR * 0.55, R * 0.24, innerR * 1.9, R * 0.14,
        innerR * math.cos(sweep * 0.45), innerR * math.sin(sweep * 0.45));
    path.arcTo(Rect.fromCircle(center: Offset.zero, radius: innerR),
        sweep * 0.45, -sweep * 0.90, false);
    path.close();

    // Metalik dolgu
    final bounds = Rect.fromLTWH(-outerR * 0.2, -outerR * 0.5, outerR * 1.1, outerR * 0.9);
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: const Alignment(-0.5, -1), end: const Alignment(0.5, 1),
        colors: [
          Color.lerp(color, Colors.white, 0.25)!, color,
          Color.lerp(color, Colors.black, 0.40)!,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(bounds));

    // Kafes doku
    canvas.save();
    canvas.clipPath(path);
    final p = Paint()..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.6..style = PaintingStyle.stroke;
    const step = 9.0;
    for (double d = -R; d < R * 2; d += step) {
      canvas.drawLine(Offset(d - R, -R), Offset(d + R, R), p);
      canvas.drawLine(Offset(d - R, R), Offset(d + R, -R), p);
    }
    canvas.restore();

    // Kenar
    canvas.drawPath(path, Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke..strokeWidth = 0.9);

    // Bearing
    final bc = Offset(outerR * math.cos(0.18), outerR * math.sin(0.18));
    canvas.drawCircle(bc, bearingR, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.38, -0.38),
        colors: [const Color(0xFFF0F0F0), const Color(0xFFAAAAAA), const Color(0xFF444444)],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: bc, radius: bearingR)));
    canvas.drawCircle(bc, bearingR * 0.62, Paint()..color = const Color(0xFF1A1A2E));
    canvas.drawCircle(bc + Offset(-bearingR * 0.22, -bearingR * 0.22),
        bearingR * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.65));
  }

  void _drawCenterHub(Canvas canvas, double R) {
    final hubR = R * 0.17;
    // Krom
    canvas.drawCircle(Offset.zero, hubR, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: [
          Colors.white.withValues(alpha: 0.95), const Color(0xFFDDDDDD),
          const Color(0xFF888888), const Color(0xFF2A2A2A),
        ],
        stops: const [0.0, 0.25, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: hubR)));
    canvas.drawCircle(Offset.zero, hubR * 0.63, Paint()..color = const Color(0xFF0D0D20));
    canvas.drawCircle(Offset.zero, hubR * 0.43, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.3, -0.3),
        colors: [
          Color.lerp(_speedColor, Colors.white, 0.3)!, _speedColor,
          Color.lerp(_speedColor, Colors.black, 0.4)!,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: hubR * 0.43)));
    canvas.drawCircle(const Offset(-1.5, -1.5), hubR * 0.13,
        Paint()..color = Colors.white.withValues(alpha: 0.75));
    canvas.drawCircle(Offset.zero, hubR, Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(covariant _DamagedSpinnerPainter old) => true;
}

// ══════════════════════════════════════════════
//  Kopan Kol Parçası — SpinnerPainter kol görseli ile uzayda süzülür
// ══════════════════════════════════════════════
class _ArmShard {
  double x, y, vx, vy, angle, rotSpeed;
  int armIndex;
  Color color;
  double size;
  _ArmShard({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.angle, required this.rotSpeed,
    required this.armIndex, required this.color,
    this.size = 1.0,
  });
}

class _ArmShardPainter extends CustomPainter {
  final List<_ArmShard> shards;
  final List<Color> colors;
  _ArmShardPainter(this.shards, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in shards) {
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.scale(s.size);
      canvas.rotate(s.angle);

      final R = 55.0;
      final outerR = R * 0.72;
      final bearingR = R * 0.115;
      final innerR = R * 0.19;
      const sweep = 0.50;

      // Glow
      canvas.drawCircle(Offset.zero, 25, Paint()
        ..color = s.color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));

      // Kol path
      final path = Path();
      path.moveTo(innerR * math.cos(-sweep * 0.45), innerR * math.sin(-sweep * 0.45));
      path.cubicTo(innerR * 1.8, -R * 0.08, outerR * 0.50, -R * 0.28, outerR * 0.82, -R * 0.22);
      final bx = outerR * math.cos(sweep * 0.20);
      final by = outerR * math.sin(-sweep * 0.30);
      path.arcTo(
        Rect.fromCircle(center: Offset(bx, by), radius: bearingR),
        math.atan2(-R * 0.22 - by, outerR * 0.82 - bx) - 0.1,
        math.pi * 1.25, false,
      );
      path.cubicTo(outerR * 0.55, R * 0.24, innerR * 1.9, R * 0.14,
          innerR * math.cos(sweep * 0.45), innerR * math.sin(sweep * 0.45));
      path.close();

      // Dolgu
      final bounds = Rect.fromLTWH(-outerR * 0.2, -outerR * 0.5, outerR * 1.1, outerR * 0.9);
      canvas.drawPath(path, Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.5, -1), end: const Alignment(0.5, 1),
          colors: [
            Color.lerp(s.color, Colors.white, 0.25)!, s.color,
            Color.lerp(s.color, Colors.black, 0.40)!,
          ],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(bounds));

      // Kenar
      canvas.drawPath(path, Paint()
        ..color = s.color.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke..strokeWidth = 1.0);

      // Bearing
      final bc = Offset(outerR * math.cos(0.18), outerR * math.sin(0.18));
      canvas.drawCircle(bc, bearingR, Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.38),
          colors: [const Color(0xFFF0F0F0), const Color(0xFFAAAAAA), const Color(0xFF444444)],
        ).createShader(Rect.fromCircle(center: bc, radius: bearingR)));
      canvas.drawCircle(bc, bearingR * 0.62, Paint()..color = const Color(0xFF1A1A2E));

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ArmShardPainter old) => true;
}

// ══════════════════════════════════════════════
//  Kırıntılar
// ══════════════════════════════════════════════
class _Debris {
  double x, y, vx, vy, rotation, rotSpeed, size, life;
  Color color;
  int type;
  _Debris({
    required this.x, required this.y, required this.vx, required this.vy,
    required this.rotation, required this.rotSpeed,
    required this.size, required this.life,
    required this.color, required this.type,
  });
}

class _DebrisPainter extends CustomPainter {
  final List<_Debris> debris;
  _DebrisPainter(this.debris);

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in debris) {
      const alpha = 0.85; // kalıcı parçalar
      canvas.save();
      canvas.translate(d.x, d.y);
      canvas.rotate(d.rotation);

      // Glow
      canvas.drawCircle(Offset.zero, d.size * 0.6, Paint()
        ..color = d.color.withValues(alpha: alpha * 0.3)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, d.size * 0.5));

      final paint = Paint()..color = d.color.withValues(alpha: alpha * 0.85);

      switch (d.type) {
        case 0: // üçgen
          final p = Path()..moveTo(0, -d.size * 0.5)
            ..lineTo(-d.size * 0.4, d.size * 0.3)
            ..lineTo(d.size * 0.4, d.size * 0.3)..close();
          canvas.drawPath(p, paint);
          break;
        case 1: // dörtgen
          canvas.drawRect(Rect.fromCenter(
            center: Offset.zero, width: d.size * 0.7, height: d.size * 0.4), paint);
          break;
        default: // daire
          canvas.drawCircle(Offset.zero, d.size * 0.3, paint);
          canvas.drawCircle(Offset(-d.size * 0.08, -d.size * 0.08),
              d.size * 0.12, Paint()..color = Colors.white.withValues(alpha: alpha * 0.4));
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _DebrisPainter old) => true;
}
