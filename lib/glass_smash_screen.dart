import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_state.dart';
import 'sound_engine.dart';
import 'l10n/app_localizations.dart';
import 'ad_manager.dart';

// ════════════════════════════════════════════════════════════════════
//  CAM KIRMA MODU — Premium Yeniden Tasarım
// ════════════════════════════════════════════════════════════════════

class GlassSmashScreen extends StatefulWidget {
  const GlassSmashScreen({super.key});
  @override
  State<GlassSmashScreen> createState() => _GlassSmashScreenState();
}

// ── Veri Modelleri ──

class _GlassObject {
  final String key;
  final String emoji;
  final Color primaryColor;
  final Color glowColor;
  final Color shardColor;
  final int maxHP;
  final double scale; // 0.7 - 1.3

  const _GlassObject({
    required this.key,
    required this.emoji,
    required this.primaryColor,
    required this.glowColor,
    required this.shardColor,
    required this.maxHP,
    this.scale = 1.0,
  });
}

class _Shard {
  double x, y, vx, vy, angle, spin, w, h, opacity;
  Color color;
  Color edgeColor;
  int shape;
  bool onGround;
  double bounceCount;
  double shimmer; // cam ışık yansıması fazı
  _Shard({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.angle, required this.spin,
    required this.w, required this.h,
    required this.color, required this.shape,
    Color? edgeColor,
    this.opacity = 1.0, this.onGround = false,
    this.bounceCount = 0, this.shimmer = 0,
  }) : edgeColor = edgeColor ?? color;
}

class _Spark {
  double x, y, vx, vy, life, maxLife, size;
  Color color;
  _Spark({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.life, required this.maxLife,
    required this.size, required this.color,
  });
}

class _ImpactRing {
  double x, y, radius, maxRadius, life;
  Color color;
  _ImpactRing({
    required this.x, required this.y,
    required this.maxRadius, required this.color,
    this.radius = 0, this.life = 1.0,
  });
}

class _CrackLine {
  final List<Offset> points;
  final double width;
  final Color color;
  _CrackLine(this.points, this.width, this.color);
}

class _DustMote {
  double x, y, vx, vy, size, life;
  Color color;
  _DustMote({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.color,
    this.life = 1.0,
  });
}

// ── State ──

class _GlassSmashScreenState extends State<GlassSmashScreen>
    with TickerProviderStateMixin {
  late AnimationController _loop;
  final _rng = math.Random();

  final List<_Shard> _shards = [];
  final List<_Spark> _sparks = [];
  final List<_ImpactRing> _rings = [];
  final List<_CrackLine> _cracks = [];
  final List<_DustMote> _dust = [];

  double _flashAlpha = 0;
  double _shake = 0;
  double _shakeAngle = 0;
  double _wobble = 0;
  double _pulsePhase = 0;
  double _ambientPhase = 0;

  static const List<_GlassObject> _objects = [
    _GlassObject(
      key: 'glass', emoji: '🥃',
      primaryColor: Color(0xFF64D2FF),
      glowColor: Color(0xFF00C6FF),
      shardColor: Color(0xFFB8ECFF),
      maxHP: 5, scale: 0.9,
    ),
    _GlassObject(
      key: 'bottle', emoji: '🍾',
      primaryColor: Color(0xFF4ADE80),
      glowColor: Color(0xFF22C55E),
      shardColor: Color(0xFFBBF7D0),
      maxHP: 8, scale: 1.1,
    ),
    _GlassObject(
      key: 'vase', emoji: '🏺',
      primaryColor: Color(0xFFF472B6),
      glowColor: Color(0xFFEC4899),
      shardColor: Color(0xFFFCE7F3),
      maxHP: 7, scale: 1.0,
    ),
    _GlassObject(
      key: 'jug', emoji: '💧',
      primaryColor: Color(0xFF60A5FA),
      glowColor: Color(0xFF3B82F6),
      shardColor: Color(0xFFDBEAFE),
      maxHP: 12, scale: 1.2,
    ),
    _GlassObject(
      key: 'plate', emoji: '🍽️',
      primaryColor: Color(0xFFC084FC),
      glowColor: Color(0xFFA855F7),
      shardColor: Color(0xFFF3E8FF),
      maxHP: 4, scale: 0.95,
    ),
  ];

  int _idx = 0;
  late int _hp;
  int _smashed = 0;
  // ignore: unused_field
  int _totalHits = 0;

  _GlassObject get _obj => _objects[_idx];
  double get _objX => MediaQuery.of(context).size.width / 2;
  double get _objY => MediaQuery.of(context).size.height * 0.36;
  double get _dmg => 1.0 - (_hp / _obj.maxHP);

  @override
  void initState() {
    super.initState();
    AdManager.instance.onScreenChange();
    GameState.instance.trackMode('glass');
    _hp = _objects[0].maxHP;
    _loop = AnimationController(vsync: this, duration: const Duration(days: 1))
      ..addListener(_update)
      ..forward();
  }

  DateTime _lastTick = DateTime.now();

  void _update() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    _shake *= 0.86;
    _flashAlpha *= 0.82;
    _wobble *= 0.88;
    _pulsePhase += dt * 2.5;
    _ambientPhase += dt * 0.8;

    // ── Shards fiziği — gerçekçi cam kırığı simülasyonu ──
    for (final s in _shards) {
      if (s.onGround) {
        // Yerde kayma + yavaşlama
        s.vx *= (1.0 - dt * 3.0); // sürtünme
        s.x += s.vx * dt;
        s.spin *= (1.0 - dt * 5.0);
        s.angle += s.spin * dt;
        s.opacity = (s.opacity - dt * 0.12).clamp(0.0, 1.0);
        continue;
      }

      // Hava sürtünmesi (boyuta göre — küçük parçalar daha çok etkilenir)
      final drag = 1.0 - (dt * (2.5 + 8.0 / (s.w + s.h + 1)));
      s.vx *= drag;
      s.vy *= drag;

      s.x += s.vx * dt;
      s.y += s.vy * dt;
      s.vy += 680 * dt; // gerçekçi yerçekimi
      s.angle += s.spin * dt;
      s.shimmer += dt * 12; // ışık yansıması animasyonu

      // Zemin çarpma — gerçekçi sekme
      final groundY = sh - 50;
      if (s.y > groundY) {
        s.y = groundY;
        s.bounceCount++;

        final impactSpeed = s.vy.abs();

        // Çarpma sparkları — hıza göre
        if (impactSpeed > 60) {
          final sparkCount = (impactSpeed / 60).round().clamp(1, 5);
          for (int j = 0; j < sparkCount; j++) {
            _sparks.add(_Spark(
              x: s.x + (_rng.nextDouble() - 0.5) * s.w,
              y: s.y,
              vx: (_rng.nextDouble() - 0.5) * impactSpeed * 0.4,
              vy: -_rng.nextDouble() * impactSpeed * 0.3 - 15,
              life: 0.15 + _rng.nextDouble() * 0.2,
              maxLife: 0.35,
              size: 1.0 + _rng.nextDouble() * 2.0,
              color: Color.lerp(s.color, Colors.white, 0.5 + _rng.nextDouble() * 0.5)!,
            ));
          }
          // Toz bulutu çarpma noktasında
          if (impactSpeed > 120) {
            _dust.add(_DustMote(
              x: s.x, y: s.y,
              vx: (_rng.nextDouble() - 0.5) * 15,
              vy: -5 - _rng.nextDouble() * 15,
              size: 6 + _rng.nextDouble() * 10,
              color: s.color.withValues(alpha: 0.08),
            ));
          }
        }

        // Enerji kaybı — her sekmede azalır
        final restitution = (0.35 - s.bounceCount * 0.08).clamp(0.05, 0.35);
        s.vy = -impactSpeed * restitution;
        s.vx *= (0.7 - s.bounceCount * 0.1).clamp(0.2, 0.7);
        s.spin *= (0.5 - s.bounceCount * 0.1).clamp(0.1, 0.5);

        // 3+ sekme veya çok yavaş → yere yapış
        if (s.bounceCount >= 3 || impactSpeed < 25) {
          s.onGround = true;
          s.vy = 0;
        }
      }

      // Duvarlar — hafif sekme
      if (s.x < 5) {
        s.x = 5;
        s.vx = s.vx.abs() * 0.25;
        s.spin += (_rng.nextDouble() - 0.5) * 3;
      }
      if (s.x > sw - 5) {
        s.x = sw - 5;
        s.vx = -s.vx.abs() * 0.25;
        s.spin += (_rng.nextDouble() - 0.5) * 3;
      }
    }
    _shards.removeWhere((s) => s.opacity <= 0);
    if (_shards.length > 300) _shards.removeRange(0, _shards.length - 300);

    // ── Sparks ──
    for (final sp in _sparks) {
      sp.x += sp.vx * dt;
      sp.y += sp.vy * dt;
      sp.vy += 250 * dt;
      sp.life -= dt;
    }
    _sparks.removeWhere((sp) => sp.life <= 0);
    if (_sparks.length > 200) _sparks.removeRange(0, _sparks.length - 200);

    // ── Rings ──
    for (final r in _rings) {
      r.radius += (r.maxRadius - r.radius) * 6 * dt;
      r.life -= dt * 2.8;
    }
    _rings.removeWhere((r) => r.life <= 0);

    // ── Dust ──
    for (final d in _dust) {
      d.x += d.vx * dt;
      d.y += d.vy * dt;
      d.vy -= 15 * dt; // yavaşça yukarı
      d.life -= dt * 0.6;
    }
    _dust.removeWhere((d) => d.life <= 0);
    if (_dust.length > 100) _dust.removeRange(0, _dust.length - 100);

    setState(() {});
  }

  void _onTap(TapDownDetails d) {
    final tx = d.globalPosition.dx;
    final ty = d.globalPosition.dy;

    // Yerdeki parçaları it
    for (final s in _shards) {
      final dist = _dist(tx, ty, s.x, s.y);
      if (dist < 50) {
        final a = math.atan2(s.y - ty, s.x - tx);
        s.vx += math.cos(a) * 200;
        s.vy += math.sin(a) * 200 - 100;
        s.spin += (_rng.nextDouble() - 0.5) * 12;
        s.onGround = false;
        HapticFeedback.selectionClick();
      }
    }

    if (_hp <= 0) return;

    // Hit testi
    final dist = _dist(tx, ty, _objX, _objY);
    final objW = 140.0 * _obj.scale;
    final objH = 200.0 * _obj.scale;
    final hitR = math.max(objW, objH) * 0.55;
    if (dist > hitR) return;

    // ── VURUŞ ──
    SoundEngine.glassHit(damage: _dmg);
    _hp--;
    _totalHits++;

    // RPM
    final rpmAmount = 20.0 + _dmg * 30;
    final newBadges = GameState.instance.addRpm(rpmAmount);
    if (newBadges.isNotEmpty && mounted) {
      BadgeCelebration.show(context, newBadges.last);
    }

    _shake = 10 + _dmg * 15;
    _shakeAngle = _rng.nextDouble() * 6.28;
    _wobble = 0.06 + _dmg * 0.08;
    _flashAlpha = 0.15 + _dmg * 0.35;

    // Impact ring
    _rings.add(_ImpactRing(
      x: tx, y: ty,
      maxRadius: 50 + _dmg * 50,
      color: _obj.glowColor,
    ));

    // Sparklar
    final sparkCount = 10 + (_dmg * 25).toInt();
    for (int i = 0; i < sparkCount; i++) {
      final a = _rng.nextDouble() * 6.28;
      final spd = 80 + _rng.nextDouble() * 300;
      _sparks.add(_Spark(
        x: tx, y: ty,
        vx: math.cos(a) * spd,
        vy: math.sin(a) * spd - 100,
        life: 0.3 + _rng.nextDouble() * 0.5,
        maxLife: 0.8,
        size: 1.5 + _rng.nextDouble() * 3.5,
        color: Color.lerp(_obj.shardColor, Colors.white, _rng.nextDouble() * 0.5)!,
      ));
    }

    // Çatlak
    _addCracks(tx, ty);

    // Küçük parça kopmalar
    _spawnShards(tx, ty, 3 + _rng.nextInt(4), small: true);

    // Toz bulutu
    for (int i = 0; i < 5; i++) {
      _dust.add(_DustMote(
        x: tx + (_rng.nextDouble() - 0.5) * 30,
        y: ty + (_rng.nextDouble() - 0.5) * 30,
        vx: (_rng.nextDouble() - 0.5) * 20,
        vy: -10 - _rng.nextDouble() * 20,
        size: 8 + _rng.nextDouble() * 15,
        color: _obj.shardColor.withValues(alpha: 0.15),
      ));
    }

    // Tamamen kırıldı
    if (_hp <= 0) {
      _smashed++;
      _flashAlpha = 0.7;
      _shake = 30;
      SoundEngine.glassShatter();
      GameState.instance.addGlassSmash();

      // Kırılma bonusu RPM
      final breakBadges = GameState.instance.addRpm(200);
      if (breakBadges.isNotEmpty && mounted) {
        BadgeCelebration.show(context, breakBadges.last);
      }

      // Büyük patlama
      _spawnShards(_objX, _objY, 60 + _rng.nextInt(30), small: false);

      // Büyük sparklar
      for (int i = 0; i < 50; i++) {
        final a = _rng.nextDouble() * 6.28;
        final spd = 120 + _rng.nextDouble() * 400;
        _sparks.add(_Spark(
          x: _objX, y: _objY,
          vx: math.cos(a) * spd,
          vy: math.sin(a) * spd - 180,
          life: 0.5 + _rng.nextDouble() * 0.8,
          maxLife: 1.3,
          size: 2 + _rng.nextDouble() * 5,
          color: Color.lerp(_obj.shardColor, Colors.white, _rng.nextDouble())!,
        ));
      }

      // Büyük ring + ikincil ring
      _rings.add(_ImpactRing(x: _objX, y: _objY, maxRadius: 200, color: Colors.white));
      _rings.add(_ImpactRing(x: _objX, y: _objY, maxRadius: 140, color: _obj.glowColor));

      // Toz bulutu
      for (int i = 0; i < 20; i++) {
        _dust.add(_DustMote(
          x: _objX + (_rng.nextDouble() - 0.5) * 80,
          y: _objY + (_rng.nextDouble() - 0.5) * 80,
          vx: (_rng.nextDouble() - 0.5) * 40,
          vy: -20 - _rng.nextDouble() * 40,
          size: 15 + _rng.nextDouble() * 30,
          color: _obj.shardColor.withValues(alpha: 0.1),
        ));
      }
    }
  }

  void _addCracks(double hitX, double hitY) {
    // Çatlaklar obje merkezine göre lokal koordinat
    final localX = hitX - (_objX - 70 * _obj.scale);
    final localY = hitY - (_objY - 100 * _obj.scale);

    final numCracks = 2 + _rng.nextInt(3);
    for (int i = 0; i < numCracks; i++) {
      final pts = <Offset>[Offset(localX, localY)];
      double px = localX, py = localY;
      final segs = 4 + _rng.nextInt(7);
      final baseAngle = _rng.nextDouble() * 6.28;
      for (int j = 0; j < segs; j++) {
        final angle = baseAngle + j * 0.25 + (_rng.nextDouble() - 0.5) * 1.4;
        final len = 6 + _rng.nextDouble() * 20;
        px += math.cos(angle) * len;
        py += math.sin(angle) * len;
        pts.add(Offset(px, py));
      }
      _cracks.add(_CrackLine(
        pts, 0.6 + _rng.nextDouble() * 1.8,
        Color.lerp(Colors.white, _obj.shardColor, _rng.nextDouble() * 0.4)!,
      ));
    }
  }

  void _spawnShards(double ox, double oy, int count, {required bool small}) {
    for (int i = 0; i < count; i++) {
      final a = _rng.nextDouble() * 6.28;

      // Boyuta göre hız — büyük parçalar yavaş, küçükler hızlı
      double spd, sz;
      if (small) {
        spd = 60 + _rng.nextDouble() * 180;
        sz = 2.0 + _rng.nextDouble() * 7;
      } else {
        // Büyük kırılmada hem büyük hem küçük parçalar
        final isBig = _rng.nextDouble() < 0.25;
        if (isBig) {
          spd = 80 + _rng.nextDouble() * 200;
          sz = 15.0 + _rng.nextDouble() * 18;
        } else {
          spd = 140 + _rng.nextDouble() * 380;
          sz = 4.0 + _rng.nextDouble() * 12;
        }
      }

      // Renk çeşitliliği — cam kırığı gerçekçiliği
      final t = _rng.nextDouble();
      Color c, ec;
      if (t < 0.2) {
        // Saydam beyaz cam
        c = Colors.white.withValues(alpha: 0.35 + _rng.nextDouble() * 0.35);
        ec = Colors.white.withValues(alpha: 0.6);
      } else if (t < 0.4) {
        // Ana renk — koyu
        c = Color.lerp(_obj.primaryColor, Colors.black, 0.15 + _rng.nextDouble() * 0.2)!;
        ec = _obj.primaryColor;
      } else if (t < 0.6) {
        // Ana renk — açık
        c = Color.lerp(_obj.primaryColor, Colors.white, 0.4 + _rng.nextDouble() * 0.3)!;
        ec = Color.lerp(_obj.shardColor, Colors.white, 0.3)!;
      } else if (t < 0.8) {
        // Glow rengi
        c = Color.lerp(_obj.glowColor, Colors.white, 0.2 + _rng.nextDouble() * 0.4)!;
        ec = _obj.glowColor;
      } else {
        // Saf kristal
        c = _obj.shardColor.withValues(alpha: 0.5 + _rng.nextDouble() * 0.5);
        ec = Colors.white.withValues(alpha: 0.5);
      }

      // Parça şekli — uzun ince / geniş / üçgen / düzensiz
      final shapeType = _rng.nextInt(7); // 7 farklı kırılma şekli
      final aspectRatio = shapeType < 2
          ? 0.2 + _rng.nextDouble() * 0.3  // uzun ince
          : shapeType < 4
              ? 0.5 + _rng.nextDouble() * 0.5  // kare-ish
              : 0.3 + _rng.nextDouble() * 0.7; // karışık

      _shards.add(_Shard(
        x: ox + (_rng.nextDouble() - 0.5) * (small ? 15 : 40),
        y: oy + (_rng.nextDouble() - 0.5) * (small ? 15 : 40),
        vx: math.cos(a) * spd + (_rng.nextDouble() - 0.5) * 60,
        vy: math.sin(a) * spd - (small ? 100 : 250),
        angle: _rng.nextDouble() * 6.28,
        spin: (_rng.nextDouble() - 0.5) * (small ? 14 : 20),
        w: sz * aspectRatio * (0.8 + _rng.nextDouble() * 0.4),
        h: sz * (0.6 + _rng.nextDouble() * 0.4),
        color: c,
        edgeColor: ec,
        shape: shapeType,
      ));
    }
  }

  void _reset() {
    setState(() {
      _shards.clear();
      _sparks.clear();
      _rings.clear();
      _cracks.clear();
      _dust.clear();
      _hp = _obj.maxHP;
      _flashAlpha = 0;
      _shake = 0;
      _wobble = 0;
    });
  }

  void _select(int i) {
    if (i == _idx) return;
    setState(() {
      _idx = i;
      _shards.clear();
      _sparks.clear();
      _rings.clear();
      _cracks.clear();
      _dust.clear();
      _hp = _obj.maxHP;
      _flashAlpha = 0;
      _shake = 0;
      _wobble = 0;
    });
  }

  String _localizedGlassName(BuildContext context, String key) {
    final l = AppLocalizations.of(context);
    if (l == null) return key;
    switch (key) {
      case 'glass': return l.glassGlass;
      case 'bottle': return l.glassBottle;
      case 'vase': return l.glassVase;
      case 'jug': return l.glassJug;
      case 'plate': return l.glassPlate;
      default: return key;
    }
  }

  double _dist(double x1, double y1, double x2, double y2) =>
      math.sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));

  @override
  void dispose() {
    GameState.instance.save();
    _loop.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final shakeX = _shake * math.cos(_shakeAngle) * (_rng.nextDouble() - 0.5);
    final shakeY = _shake * math.sin(_shakeAngle) * (_rng.nextDouble() - 0.5);
    final l = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF030308),
      body: GestureDetector(
        onTapDown: _onTap,
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: Offset(shakeX, shakeY),
          child: Stack(
            children: [
              // ── Arka plan ──
              RepaintBoundary(
                child: CustomPaint(
                  size: sz,
                  painter: _BGPainter(
                    primaryColor: _obj.primaryColor,
                    glowColor: _obj.glowColor,
                    ambientPhase: _ambientPhase,
                    dmg: _dmg,
                  ),
                ),
              ),

              // ── Oyun katmanı ──
              RepaintBoundary(
                child: CustomPaint(
                  size: sz,
                  painter: _GamePainter(
                    shards: _shards,
                    sparks: _sparks,
                    rings: _rings,
                    dust: _dust,
                  ),
                ),
              ),

              // ── Cam Obje ──
              if (_hp > 0)
                Positioned(
                  left: _objX - 70 * _obj.scale,
                  top: _objY - 100 * _obj.scale,
                  child: Transform.rotate(
                    angle: math.sin(_wobble * 80) * _wobble,
                    child: CustomPaint(
                      size: Size(140 * _obj.scale, 200 * _obj.scale),
                      painter: _GlassObjPainter(
                        obj: _obj,
                        dmg: _dmg,
                        cracks: _cracks,
                        pulsePhase: _pulsePhase,
                      ),
                    ),
                  ),
                ),

              // ── Flash ──
              if (_flashAlpha > 0.01)
                IgnorePointer(
                  child: Container(
                    width: sz.width, height: sz.height,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(
                          (_objX / sz.width) * 2 - 1,
                          (_objY / sz.height) * 2 - 1,
                        ),
                        radius: 0.8,
                        colors: [
                          _obj.glowColor.withValues(alpha: _flashAlpha * 0.4),
                          Colors.white.withValues(alpha: _flashAlpha * 0.15),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

              // ── Üst bar ──
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      _iconBtn(Icons.arrow_back_rounded, () => Navigator.pop(context)),
                      const SizedBox(width: 14),
                      ShaderMask(
                        shaderCallback: (r) => LinearGradient(
                          colors: [_obj.primaryColor, _obj.glowColor, Colors.white70],
                        ).createShader(r),
                        child: Text(
                          l?.menuGlass.toUpperCase() ?? 'CAM KIRMA',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Kırılan sayacı
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: _obj.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _obj.primaryColor.withValues(alpha: 0.15)),
                        ),
                        child: Row(children: [
                          const Text('💥', style: TextStyle(fontSize: 14)),
                          const SizedBox(width: 5),
                          Text('$_smashed', style: const TextStyle(
                            color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                    ],
                  ),
                ),
              ),

              // ── HP bar ──
              if (_hp > 0)
                Positioned(
                  left: _objX - 80,
                  top: _objY + 100 * _obj.scale + 20,
                  width: 160,
                  child: Column(children: [
                    // Bar
                    Container(
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LayoutBuilder(builder: (_, box) => Stack(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: box.maxWidth * (_hp / _obj.maxHP),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              gradient: LinearGradient(
                                colors: _dmg < 0.4
                                    ? [_obj.primaryColor, _obj.glowColor]
                                    : _dmg < 0.7
                                        ? [const Color(0xFFFFB74D), const Color(0xFFFFA726)]
                                        : [const Color(0xFFEF5350), const Color(0xFFE53935)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_dmg < 0.4 ? _obj.glowColor : _dmg < 0.7 ? Colors.orange : Colors.red)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ])),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$_hp / ${_obj.maxHP}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10, fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),

              // ── Kırıldı mesajı ──
              if (_hp <= 0)
                Positioned(
                  left: 0, right: 0, top: _objY - 40,
                  child: Column(children: [
                    ShaderMask(
                      shaderCallback: (r) => LinearGradient(
                        colors: [_obj.primaryColor, Colors.white, _obj.glowColor],
                      ).createShader(r),
                      child: Text(
                        l?.glassSmashed ?? 'PARAMPARÇA!',
                        style: TextStyle(
                          fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: 5,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: _obj.glowColor.withValues(alpha: 0.6), blurRadius: 25),
                            Shadow(color: _obj.glowColor.withValues(alpha: 0.3), blurRadius: 50),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l?.glassAction ?? 'Dokunarak parçaları fırlat!',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                    ),
                  ]),
                ),

              // ── İpucu ──
              if (_hp > 0 && _smashed == 0 && _dmg == 0)
                Positioned(
                  left: 0, right: 0, top: _objY + 100 * _obj.scale + 60,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(seconds: 2),
                    builder: (_, v, child) => Opacity(
                      opacity: (math.sin(v * 6.28) * 0.5 + 0.5),
                      child: child,
                    ),
                    child: Text(
                      '👊 ${AppLocalizations.of(context)?.glassHitToSmash ?? 'SMASH IT!'}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white24, fontSize: 14,
                        letterSpacing: 3, fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

              // ── Obje seçici ──
              Positioned(
                left: 0, right: 0, bottom: 75,
                child: SizedBox(
                  height: 75,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _objects.length,
                    itemBuilder: (_, i) {
                      final o = _objects[i];
                      final sel = i == _idx;
                      return GestureDetector(
                        onTap: () => _select(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          width: 70, height: 70,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: sel
                                ? o.primaryColor.withValues(alpha: 0.15)
                                : Colors.white.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: sel
                                  ? o.primaryColor.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.05),
                              width: sel ? 2 : 1,
                            ),
                            boxShadow: sel ? [
                              BoxShadow(color: o.glowColor.withValues(alpha: 0.2), blurRadius: 15),
                            ] : null,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(o.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 3),
                              Text(
                                _localizedGlassName(context, o.key),
                                style: TextStyle(
                                  color: sel ? Colors.white : Colors.white30,
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── Yenile butonu ──
              Positioned(
                left: 40, right: 40, bottom: 66,
                child: GestureDetector(
                  onTap: _reset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        _obj.primaryColor.withValues(alpha: 0.4),
                        _obj.glowColor.withValues(alpha: 0.15),
                      ]),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _obj.primaryColor.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          l?.glassReset ?? 'YENİDEN',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
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
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Icon(icon, color: Colors.white60, size: 20),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  Arka Plan Painter — dinamik gradient + ambient parçacıklar
// ════════════════════════════════════════════════════════════════════

class _BGPainter extends CustomPainter {
  final Color primaryColor;
  final Color glowColor;
  final double ambientPhase;
  final double dmg;

  _BGPainter({
    required this.primaryColor,
    required this.glowColor,
    required this.ambientPhase,
    required this.dmg,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Koyu gradient arka plan
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..shader = RadialGradient(
        center: const Alignment(0, -0.2),
        radius: 1.3,
        colors: [
          Color.lerp(const Color(0xFF080818), primaryColor, 0.03)!,
          const Color(0xFF040410),
          const Color(0xFF020208),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Objeye doğru yumuşak ambient glow
    final glowY = h * 0.36;
    canvas.drawCircle(
      Offset(w / 2, glowY),
      120 + math.sin(ambientPhase) * 20,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glowColor.withValues(alpha: 0.04 + dmg * 0.03),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(w / 2, glowY), radius: 150)),
    );

    // Zemin çizgisi — ince
    final groundY = h - 50;
    canvas.drawLine(
      Offset(30, groundY), Offset(w - 30, groundY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.03)
        ..strokeWidth = 0.8,
    );

    // Zemin yansıma
    canvas.drawRect(
      Rect.fromLTWH(0, groundY, w, 50),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          primaryColor.withValues(alpha: 0.015),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, groundY, w, 50)),
    );

    // Ambient ışık noktaları
    final rng = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final px = rng.nextDouble() * w;
      final py = rng.nextDouble() * h;
      final pulsed = math.sin(ambientPhase * 0.5 + i * 0.7);
      canvas.drawCircle(
        Offset(px, py),
        0.5 + pulsed * 0.3,
        Paint()..color = Colors.white.withValues(alpha: 0.02 + pulsed * 0.01),
      );
    }
  }

  @override
  bool shouldRepaint(_BGPainter old) =>
      old.primaryColor != primaryColor || old.dmg != dmg;
}

// ════════════════════════════════════════════════════════════════════
//  Game Painter — Shards + Sparks + Rings + Dust
// ════════════════════════════════════════════════════════════════════

class _GamePainter extends CustomPainter {
  final List<_Shard> shards;
  final List<_Spark> sparks;
  final List<_ImpactRing> rings;
  final List<_DustMote> dust;

  _GamePainter({
    required this.shards, required this.sparks,
    required this.rings, required this.dust,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Dust ──
    for (final d in dust) {
      canvas.drawCircle(
        Offset(d.x, d.y), d.size,
        Paint()
          ..color = d.color.withValues(alpha: d.life * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, d.size * 0.7),
      );
    }

    // ── Impact Rings ──
    for (final r in rings) {
      // Outer glow
      canvas.drawCircle(
        Offset(r.x, r.y), r.radius,
        Paint()
          ..color = r.color.withValues(alpha: r.life * 0.15)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 * r.life)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 + r.life * 4,
      );
      // Inner ring
      canvas.drawCircle(
        Offset(r.x, r.y), r.radius * 0.9,
        Paint()
          ..color = Colors.white.withValues(alpha: r.life * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 + r.life * 2,
      );
    }

    // ── Shards — gerçekçi cam parçaları ──
    for (final s in shards) {
      canvas.save();
      canvas.translate(s.x, s.y);
      canvas.rotate(s.angle);

      final path = _shardPath(s);

      // Glow — uçuşurken ışık saçma
      if (s.opacity > 0.3 && !s.onGround) {
        canvas.drawCircle(Offset.zero, s.w * 0.5, Paint()
          ..color = s.color.withValues(alpha: 0.08 * s.opacity)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.w * 0.3));
      }

      // Ana cam dolgu — gradient ile derinlik
      final shimVal = math.sin(s.shimmer) * 0.15;
      canvas.drawPath(path, Paint()
        ..shader = ui.Gradient.linear(
          Offset(-s.w * 0.4, -s.h * 0.4),
          Offset(s.w * 0.4, s.h * 0.4),
          [
            Color.lerp(s.color, Colors.white, 0.15 + shimVal)!.withValues(alpha: s.opacity * 0.9),
            s.color.withValues(alpha: s.opacity * 0.8),
            Color.lerp(s.color, Colors.black, 0.2)!.withValues(alpha: s.opacity * 0.7),
          ],
          const [0.0, 0.5, 1.0],
        ));

      // Cam kenar çizgisi — farklı renk
      canvas.drawPath(path, Paint()
        ..color = s.edgeColor.withValues(alpha: 0.4 * s.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7);

      // İç cam yansıması çizgisi — hareket ederken parlar
      if (s.w > 4 && s.opacity > 0.4) {
        final reflectAlpha = (0.2 + shimVal * 0.3).clamp(0.05, 0.5) * s.opacity;
        canvas.drawLine(
          Offset(-s.w * 0.15, -s.h * 0.2),
          Offset(-s.w * 0.05, s.h * 0.15),
          Paint()
            ..color = Colors.white.withValues(alpha: reflectAlpha)
            ..strokeWidth = 0.6
            ..strokeCap = StrokeCap.round,
        );
      }

      // Büyük parçalarda ikinci yansıma
      if (s.w > 10 && s.opacity > 0.5) {
        canvas.drawLine(
          Offset(s.w * 0.05, -s.h * 0.1),
          Offset(s.w * 0.12, s.h * 0.2),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.12 * s.opacity)
            ..strokeWidth = 0.4,
        );
      }

      canvas.restore();
    }

    // ── Sparks ──
    for (final sp in sparks) {
      final t = (sp.life / sp.maxLife).clamp(0.0, 1.0);
      // Glow
      canvas.drawCircle(
        Offset(sp.x, sp.y),
        sp.size * t * 1.5,
        Paint()
          ..color = sp.color.withValues(alpha: t * 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sp.size),
      );
      // Core
      canvas.drawCircle(
        Offset(sp.x, sp.y),
        sp.size * t * 0.5,
        Paint()..color = Colors.white.withValues(alpha: t * 0.9),
      );
    }
  }

  Path _shardPath(_Shard s) {
    switch (s.shape) {
      // Üçgen — sivri cam kırığı
      case 0: return Path()..moveTo(0, -s.h * 0.55)..lineTo(-s.w * 0.45, s.h * 0.4)..lineTo(s.w * 0.45, s.h * 0.35)..close();
      // Dörtgen — düz cam parçası
      case 1: return Path()..moveTo(-s.w * 0.35, -s.h * 0.42)..lineTo(s.w * 0.38, -s.h * 0.28)..lineTo(s.w * 0.3, s.h * 0.42)..lineTo(-s.w * 0.42, s.h * 0.35)..close();
      // Uzun ince — iğne şekli
      case 2: return Path()..moveTo(0, -s.h * 0.6)..lineTo(s.w * 0.1, s.h * 0.1)..lineTo(0, s.h * 0.6)..lineTo(-s.w * 0.08, 0)..close();
      // Pentagon — beşgen kırılma
      case 3: return Path()..moveTo(0, -s.h * 0.48)..lineTo(s.w * 0.42, -s.h * 0.12)..lineTo(s.w * 0.28, s.h * 0.42)..lineTo(-s.w * 0.32, s.h * 0.38)..lineTo(-s.w * 0.42, -s.h * 0.18)..close();
      // Yamuk — asimetrik kırık
      case 4: return Path()..moveTo(-s.w * 0.2, -s.h * 0.5)..lineTo(s.w * 0.35, -s.h * 0.35)..lineTo(s.w * 0.42, s.h * 0.3)..lineTo(-s.w * 0.1, s.h * 0.5)..close();
      // Kama — kısa geniş
      case 5: return Path()..moveTo(0, -s.h * 0.3)..lineTo(s.w * 0.5, s.h * 0.1)..lineTo(s.w * 0.35, s.h * 0.45)..lineTo(-s.w * 0.4, s.h * 0.42)..lineTo(-s.w * 0.48, s.h * 0.05)..close();
      // Toz parçası — çok küçük düzensiz
      default: return Path()..moveTo(0, -s.h * 0.5)..lineTo(s.w * 0.3, -s.h * 0.15)..lineTo(s.w * 0.15, s.h * 0.45)..lineTo(-s.w * 0.25, s.h * 0.3)..lineTo(-s.w * 0.3, -s.h * 0.2)..close();
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ════════════════════════════════════════════════════════════════════
//  Cam Obje Painter — Premium kalite gerçekçi cam render
// ════════════════════════════════════════════════════════════════════

class _GlassObjPainter extends CustomPainter {
  final _GlassObject obj;
  final double dmg;
  final List<_CrackLine> cracks;
  final double pulsePhase;

  _GlassObjPainter({
    required this.obj,
    required this.dmg,
    required this.cracks,
    required this.pulsePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;
    final shape = _shapePath(size);

    // ── 1. Gölge ──
    canvas.save();
    canvas.translate(3, 6);
    canvas.drawPath(shape, Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.restore();

    // ── 2. Dış glow — hasar arttıkça yoğunlaşır ──
    final pulse = math.sin(pulsePhase) * 0.02;
    canvas.drawPath(shape, Paint()
      ..color = obj.glowColor.withValues(alpha: 0.06 + dmg * 0.06 + pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 25));

    // Hasar kırmızı glow
    if (dmg > 0.3) {
      canvas.drawPath(shape, Paint()
        ..color = Colors.red.withValues(alpha: (dmg - 0.3) * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 15));
    }

    // ── 3. Ana cam dolgu ──
    canvas.save();
    canvas.clipPath(shape);

    // 3a. Koyu gradient arka plan
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, -0.35),
        radius: 1.5,
        colors: [
          obj.primaryColor.withValues(alpha: 0.06),
          obj.primaryColor.withValues(alpha: 0.16),
          obj.primaryColor.withValues(alpha: 0.25),
          obj.primaryColor.withValues(alpha: 0.14),
          obj.primaryColor.withValues(alpha: 0.06),
        ],
        stops: const [0.0, 0.2, 0.45, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h)));

    // 3b. Üst parlak alan
    final topShine = Path()
      ..moveTo(0, 0)..lineTo(w, 0)
      ..lineTo(w, h * 0.28)
      ..quadraticBezierTo(cx, h * 0.16, 0, h * 0.32)..close();
    canvas.drawPath(topShine, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h * 0.32)));

    // 3c. Sol kenar highlight
    final shX = cx - w * 0.24;
    final shW = w * 0.06;
    final shinePath = Path()
      ..moveTo(shX, h * 0.06)
      ..quadraticBezierTo(shX - 2, h * 0.45, shX + 4, h * 0.85)
      ..lineTo(shX + shW + 4, h * 0.85)
      ..quadraticBezierTo(shX + shW - 2, h * 0.45, shX + shW, h * 0.06)
      ..close();
    canvas.drawPath(shinePath, Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));

    // 3d. İnce parlak çizgi
    canvas.drawPath(Path()
      ..moveTo(shX - 1, h * 0.08)
      ..quadraticBezierTo(shX - 3, h * 0.45, shX + 1, h * 0.82),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke..strokeWidth = 0.8);

    // 3e. Sağ kenar çizgi
    final rShX = cx + w * 0.18;
    canvas.drawPath(Path()
      ..moveTo(rShX, h * 0.12)
      ..quadraticBezierTo(rShX + 3, h * 0.5, rShX - 2, h * 0.78),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke..strokeWidth = 0.6);

    // 3f. Alt derinlik
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.65, w, h * 0.35),
      Paint()..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, obj.primaryColor.withValues(alpha: 0.15)],
      ).createShader(Rect.fromLTWH(0, h * 0.65, w, h * 0.35)),
    );

    // 3g. Sıvı efekti (bardak/şişe/damacana)
    if (obj.key == 'glass' || obj.key == 'bottle' || obj.key == 'jug') {
      final liquidTop = h * (obj.key == 'bottle' ? 0.50 : 0.45);
      final waveOffset = math.sin(pulsePhase * 1.5) * 4;
      final liquidPath = Path()
        ..moveTo(0, liquidTop + waveOffset)
        ..quadraticBezierTo(cx, liquidTop - 6 + waveOffset, w, liquidTop + waveOffset)
        ..lineTo(w, h)..lineTo(0, h)..close();
      canvas.drawPath(liquidPath, Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [
            obj.primaryColor.withValues(alpha: 0.12),
            obj.primaryColor.withValues(alpha: 0.28),
          ],
        ).createShader(Rect.fromLTWH(0, liquidTop, w, h - liquidTop)));
      // Sıvı yüzey parlaması
      canvas.drawLine(
        Offset(cx - w * 0.15, liquidTop + waveOffset),
        Offset(cx + w * 0.1, liquidTop + waveOffset),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12)
          ..strokeWidth = 0.7,
      );
    }

    // 3h. Tabak iç halkalar
    if (obj.key == 'plate') {
      final rimH = h * 0.12;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy - rimH), width: w * 0.80, height: h * 0.38),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.10)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy - rimH * 0.8), width: w * 0.55, height: h * 0.25),
        Paint()
          ..color = obj.primaryColor.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke..strokeWidth = 0.8,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy - rimH * 0.6), width: w * 0.30, height: h * 0.12),
        Paint()
          ..shader = RadialGradient(
            colors: [obj.primaryColor.withValues(alpha: 0.18), Colors.transparent],
          ).createShader(Rect.fromCenter(center: Offset(cx, cy - rimH * 0.6), width: w * 0.30, height: h * 0.12)),
      );
    }

    // ── 4. Çatlaklar ──
    if (cracks.isNotEmpty) {
      for (final c in cracks) {
        if (c.points.length < 2) continue;
        final crackPath = Path()..moveTo(c.points[0].dx, c.points[0].dy);
        for (int i = 1; i < c.points.length; i++) {
          crackPath.lineTo(c.points[i].dx, c.points[i].dy);
        }
        // Koyu gölge
        canvas.drawPath(crackPath, Paint()
          ..color = Colors.black.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = c.width + 1.2);
        // Beyaz çatlak
        canvas.drawPath(crackPath, Paint()
          ..color = c.color.withValues(alpha: 0.75 + dmg * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = c.width);
        // İç glow
        canvas.drawPath(crackPath, Paint()
          ..color = obj.glowColor.withValues(alpha: 0.2 + dmg * 0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = c.width * 0.4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      }

      // Hasar overlay
      canvas.drawRect(
        Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..color = Colors.red.withValues(alpha: dmg * 0.05)
          ..blendMode = BlendMode.screen,
      );
    }

    canvas.restore();

    // ── 5. Kenar çizgisi ──
    canvas.drawPath(shape, Paint()
      ..color = obj.primaryColor.withValues(alpha: 0.45 + dmg * 0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    canvas.drawPath(shape, Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke..strokeWidth = 0.5);

    // ── 6. Specular highlights ──
    canvas.drawCircle(
      Offset(cx - w * 0.15, h * 0.11),
      w * 0.05,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.50)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.03),
    );
    canvas.drawCircle(
      Offset(cx - w * 0.15, h * 0.11),
      w * 0.016,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    // İkinci specular
    canvas.drawCircle(
      Offset(cx + w * 0.08, h * 0.17),
      w * 0.022,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.015),
    );
  }

  Path _shapePath(Size size) {
    final cx = size.width / 2;
    final w = size.width, h = size.height;

    switch (obj.key) {
      case 'glass':
        return Path()
          ..moveTo(cx - w * 0.32, h * 0.04)
          ..cubicTo(cx - w * 0.34, h * 0.01, cx + w * 0.34, h * 0.01, cx + w * 0.32, h * 0.04)
          ..lineTo(cx + w * 0.26, h * 0.92)
          ..cubicTo(cx + w * 0.25, h * 0.98, cx - w * 0.25, h * 0.98, cx - w * 0.26, h * 0.92)
          ..close();
      case 'bottle':
        return Path()
          ..moveTo(cx - w * 0.09, 0)..lineTo(cx + w * 0.09, 0)
          ..lineTo(cx + w * 0.09, h * 0.07)
          ..lineTo(cx + w * 0.07, h * 0.09)
          ..lineTo(cx + w * 0.07, h * 0.27)
          ..cubicTo(cx + w * 0.07, h * 0.32, cx + w * 0.32, h * 0.38, cx + w * 0.32, h * 0.45)
          ..lineTo(cx + w * 0.32, h * 0.88)
          ..cubicTo(cx + w * 0.32, h * 0.97, cx - w * 0.32, h * 0.97, cx - w * 0.32, h * 0.88)
          ..lineTo(cx - w * 0.32, h * 0.45)
          ..cubicTo(cx - w * 0.32, h * 0.38, cx - w * 0.07, h * 0.32, cx - w * 0.07, h * 0.27)
          ..lineTo(cx - w * 0.07, h * 0.09)
          ..lineTo(cx - w * 0.09, h * 0.07)..close();
      case 'vase':
        return Path()
          ..moveTo(cx - w * 0.13, h * 0.02)
          ..cubicTo(cx - w * 0.15, 0, cx + w * 0.15, 0, cx + w * 0.13, h * 0.02)
          ..cubicTo(cx + w * 0.11, h * 0.08, cx + w * 0.09, h * 0.12, cx + w * 0.09, h * 0.18)
          ..cubicTo(cx + w * 0.09, h * 0.25, cx + w * 0.44, h * 0.35, cx + w * 0.44, h * 0.50)
          ..cubicTo(cx + w * 0.44, h * 0.70, cx + w * 0.22, h * 0.88, cx + w * 0.20, h * 0.95)
          ..cubicTo(cx + w * 0.17, h, cx - w * 0.17, h, cx - w * 0.20, h * 0.95)
          ..cubicTo(cx - w * 0.22, h * 0.88, cx - w * 0.44, h * 0.70, cx - w * 0.44, h * 0.50)
          ..cubicTo(cx - w * 0.44, h * 0.35, cx - w * 0.09, h * 0.25, cx - w * 0.09, h * 0.18)
          ..cubicTo(cx - w * 0.09, h * 0.12, cx - w * 0.11, h * 0.08, cx - w * 0.13, h * 0.02)
          ..close();
      case 'jug':
        return Path()
          ..moveTo(cx - w * 0.07, 0)..lineTo(cx + w * 0.07, 0)
          ..lineTo(cx + w * 0.07, h * 0.04)
          ..lineTo(cx + w * 0.09, h * 0.05)
          ..lineTo(cx + w * 0.09, h * 0.10)
          ..lineTo(cx + w * 0.06, h * 0.12)
          ..lineTo(cx + w * 0.06, h * 0.16)
          ..cubicTo(cx + w * 0.06, h * 0.18, cx + w * 0.40, h * 0.22, cx + w * 0.40, h * 0.30)
          ..lineTo(cx + w * 0.40, h * 0.85)
          ..cubicTo(cx + w * 0.40, h * 0.96, cx - w * 0.40, h * 0.96, cx - w * 0.40, h * 0.85)
          ..lineTo(cx - w * 0.40, h * 0.30)
          ..cubicTo(cx - w * 0.40, h * 0.22, cx - w * 0.06, h * 0.18, cx - w * 0.06, h * 0.16)
          ..lineTo(cx - w * 0.06, h * 0.12)
          ..lineTo(cx - w * 0.09, h * 0.10)
          ..lineTo(cx - w * 0.09, h * 0.05)
          ..lineTo(cx - w * 0.07, h * 0.04)..close();
      case 'plate':
        return Path()
          ..moveTo(cx - w * 0.46, h * 0.45)
          ..cubicTo(cx - w * 0.46, h * 0.15, cx - w * 0.30, h * 0.05, cx, h * 0.05)
          ..cubicTo(cx + w * 0.30, h * 0.05, cx + w * 0.46, h * 0.15, cx + w * 0.46, h * 0.45)
          ..cubicTo(cx + w * 0.46, h * 0.65, cx + w * 0.30, h * 0.80, cx + w * 0.15, h * 0.90)
          ..cubicTo(cx + w * 0.06, h * 0.96, cx - w * 0.06, h * 0.96, cx - w * 0.15, h * 0.90)
          ..cubicTo(cx - w * 0.30, h * 0.80, cx - w * 0.46, h * 0.65, cx - w * 0.46, h * 0.45)
          ..close();
      default:
        return Path()..addOval(Rect.fromCenter(center: Offset(cx, h / 2), width: w * 0.8, height: h * 0.8));
    }
  }

  @override
  bool shouldRepaint(_GlassObjPainter old) => true;
}
