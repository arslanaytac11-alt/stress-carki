import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'spinner_painter.dart';
import 'physics_engine.dart';
import 'particle_painter.dart';
import 'sound_engine.dart';
import 'audio_engine.dart';
import 'spinner_collection.dart';
import 'collection_screen.dart';
import 'breath_screen.dart';
import 'space_background_painter.dart';
import 'orbit_screen.dart';
import 'smash_screen.dart';
import 'balloon_pop_screen.dart';
import 'glass_smash_screen.dart';
import 'stress_ball_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'game_state.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'ad_manager.dart';

/// Her pointer'ın takip verisi
class _PointerData {
  DateTime lastTime;
  double lastAngle;
  double lastVelocity;
  _PointerData({required this.lastTime, required this.lastAngle, this.lastVelocity = 0.0});
}

class SpinnerScreen extends StatefulWidget {
  const SpinnerScreen({super.key});

  @override
  State<SpinnerScreen> createState() => _SpinnerScreenState();
}

class _SpinnerScreenState extends State<SpinnerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  late PhysicsEngine _physics;
  late AnimationController _gameLoop;
  late ParticleSystem _particles;

  double _currentAngle = 0.0;
  double _rpm = 0.0;
  double _maxRpm = 0.0;

  // ── Multi-touch pointer takibi ──
  final Map<int, _PointerData> _pointers = {};

  // Parıltı efekti
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Ses motorları
  final SoundEngine _sound = SoundEngine();   // haptik
  final AudioEngine _audio = AudioEngine();   // gerçek ses

  // Aktif spinner modeli
  SpinnerModel _activeSpinner = SpinnerCollection.all.first;

  // Rekor
  SharedPreferences? _prefs;
  double _allTimeMaxRpm = 0.0;

  // Widget boyutu ve merkezi
  final GlobalKey _spinnerKey = GlobalKey();
  Offset _spinnerCenter = Offset.zero;

  // ── Motion blur trail ──
  final List<double> _trailAngles = [];
  static const int _trailLength = 10;

  // Ses update sayacı
  int _audioFrame = 0;

  // ── 3D Gyroscope tilt ──
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  StreamSubscription? _gyroSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AdManager.instance.onScreenChange();
    GameState.instance.trackMode('spinner');
    _physics = PhysicsEngine();
    _particles = ParticleSystem();

    // 60 FPS oyun döngüsü
    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Gyroscope dinle (iOS'ta izin yoksa veya sensor yoksa guvenle atla)
    try {
      _gyroSub = gyroscopeEventStream().listen(
        (e) {
          _tiltX = (_tiltX * 0.85 + e.y * 0.15).clamp(-1.5, 1.5);
          _tiltY = (_tiltY * 0.85 + e.x * 0.15).clamp(-1.5, 1.5);
        },
        onError: (_) {
          _gyroSub?.cancel();
          _gyroSub = null;
        },
        cancelOnError: true,
      );
    } catch (_) {
      _gyroSub = null;
    }

    _gameLoop.forward();
    _loadRecord();
    _audio.init();
  }

  Future<void> _loadRecord() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    final savedId = prefs.getString('selected_spinner') ?? 'classic_red';
    final found = SpinnerCollection.all
        .where((s) => s.id == savedId)
        .firstOrNull;
    if (mounted) {
      setState(() {
        _allTimeMaxRpm = prefs.getDouble('max_rpm') ?? 0.0;
        if (found != null) _activeSpinner = found;
      });
    }
  }

  DateTime _lastTick = DateTime.now();
  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;
    _physics.update(dt);
    _particles.update(dt);

    // Haptik geri bildirim motoru
    _sound.update(_physics.rpm);

    // Ses motoru — her 3 frame'de bir
    _audioFrame++;
    if (_audioFrame >= 3) {
      _audioFrame = 0;
      _audio.update(_physics.rpm);
    }

    // Motion blur trail — geçmiş açıları kaydet
    if (_trailAngles.length >= _trailLength) _trailAngles.removeAt(0);
    _trailAngles.add(_physics.angle);

    // Parçacık
    if (_physics.rpm > 100) {
      _particles.emit(_spinnerCenter.dx, _spinnerCenter.dy,
          _physics.rpm, _activeSpinner.skin.colors[0]);
    }

    // Global RPM biriktir
    if (_physics.rpm > 5) {
      final earned = _physics.rpm / 60.0;
      final newBadges = GameState.instance.addRpm(earned);
      if (newBadges.isNotEmpty && mounted) {
        BadgeCelebration.show(context, newBadges.last);
      }
    }

    setState(() {
      _currentAngle = _physics.angle;
      _rpm = _physics.rpm;
      if (_rpm > _maxRpm) {
        _maxRpm = _rpm;
        if (_maxRpm > _allTimeMaxRpm) {
          _allTimeMaxRpm = _maxRpm;
          _prefs?.setDouble('max_rpm', _allTimeMaxRpm);
        }
      }
    });
  }

  double _getAngleFromOffset(Offset center, Offset touch) {
    return math.atan2(touch.dy - center.dy, touch.dx - center.dx);
  }

  void _updateSpinnerCenter() {
    final box = _spinnerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(Offset.zero);
      _spinnerCenter = pos + Offset(box.size.width / 2, box.size.height / 2);
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  Multi-touch pointer olayları
  // ═══════════════════════════════════════════════════════════

  void _onPointerDown(PointerDownEvent event) {
    _updateSpinnerCenter();
    final angle = _getAngleFromOffset(_spinnerCenter, event.position);

    // İlk parmak dokunduğunda grip + dokunma sesi
    if (_pointers.isEmpty) {
      _physics.applyGrip();
      _audio.playTouch();
    }

    _pointers[event.pointer] = _PointerData(
      lastTime: DateTime.now(),
      lastAngle: angle,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    final data = _pointers[event.pointer];
    if (data == null) return;

    final now = DateTime.now();
    final dt = now.difference(data.lastTime).inMicroseconds / 1e6;
    if (dt < 0.001 || dt > 0.1) {
      data.lastTime = now;
      data.lastAngle = _getAngleFromOffset(_spinnerCenter, event.position);
      return;
    }

    // Merkeze çok yakın parmak → aşırı açısal hız üretir, filtrele
    final dx = event.position.dx - _spinnerCenter.dx;
    final dy = event.position.dy - _spinnerCenter.dy;
    final distFromCenter = math.sqrt(dx * dx + dy * dy);
    if (distFromCenter < 30) {
      data.lastTime = now;
      data.lastAngle = _getAngleFromOffset(_spinnerCenter, event.position);
      return;
    }

    final currentAngle = _getAngleFromOffset(_spinnerCenter, event.position);
    double deltaAngle = currentAngle - data.lastAngle;

    // Açı sıçramasını düzelt
    if (deltaAngle > math.pi) deltaAngle -= 2 * math.pi;
    if (deltaAngle < -math.pi) deltaAngle += 2 * math.pi;

    // Mesafeye göre ağırlık — kenardan döndürme daha etkili
    final distFactor = ((distFromCenter - 30) / 120).clamp(0.2, 1.0);
    final fingerVelocity = (deltaAngle / dt) * distFactor;

    // ── Çift parmak: her parmak bağımsız kuvvet uygular ──
    _physics.applySwipe(fingerVelocity, dt);

    // Haptik geri bildirim (yüksek hızda)
    if (_physics.rpm > 250 && _physics.rpm % 50 < 5) {
      HapticFeedback.lightImpact();
    }

    data.lastVelocity = fingerVelocity;
    data.lastTime = now;
    data.lastAngle = currentAngle;
  }

  void _onPointerUp(PointerUpEvent event) {
    final data = _pointers.remove(event.pointer);
    if (data != null) {
      _physics.applyFlick(data.lastVelocity);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointers.remove(event.pointer);
    if (_pointers.isEmpty) _physics.releaseFinger();
  }

  void _openCollection() {
    _pauseEngine();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CollectionScreen(
          allTimeMaxRpm: _allTimeMaxRpm,
          selectedId: _activeSpinner.id,
          onSelect: (s) {
            setState(() => _activeSpinner = s);
            _prefs?.setString('selected_spinner', s.id);
          },
        ),
      ),
    ).then((_) => _resumeEngine());
  }

  void _openBreathMode() {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => const BreathScreen()));
  }

  void _resetSession() {
    setState(() {
      _maxRpm = 0;
      _physics.angularVelocity = 0;
    });
  }

  void _showBadgesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0820),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final l = AppLocalizations.of(sheetCtx)!;
        final gs = GameState.instance;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: Colors.white24, borderRadius: BorderRadius.circular(2),
                )),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.military_tech, color: Color(0xFFFFD700), size: 22),
                    const SizedBox(width: 8),
                    Text(l.badgesTitle, style: const TextStyle(
                      color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 3,
                    )),
                  ],
                ),
                const SizedBox(height: 6),
                Text(l.badgesTotal(gs.formattedRpm), style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12,
                )),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: GameState.badges.length,
                    itemBuilder: (_, i) {
                      final b = GameState.badges[i];
                      final earned = gs.earnedBadges.contains(b.id);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: earned ? b.color.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: earned ? b.color.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(earned ? b.emoji : '🔒', style: TextStyle(fontSize: 24,
                              color: earned ? null : Colors.white.withValues(alpha: 0.2),
                            )),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(localizedBadgeName(sheetCtx, b.id), style: TextStyle(
                                  color: earned ? Colors.white : Colors.white38,
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                )),
                                Text('${b.threshold.toStringAsFixed(0)} RPM', style: TextStyle(
                                  color: earned ? b.color.withValues(alpha: 0.7) : Colors.white24,
                                  fontSize: 11,
                                )),
                              ],
                            )),
                            if (earned)
                              Icon(Icons.check_circle, color: b.color, size: 20)
                            else
                              Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.15), size: 18),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  void _showLanguageDialog() {
    final languages = [
      ('TR', 'Türkçe', 'tr', const Color(0xFFE30A17)),
      ('EN', 'English', 'en', const Color(0xFF1A237E)),
      ('DE', 'Deutsch', 'de', const Color(0xFFDD0000)),
      ('FR', 'Français', 'fr', const Color(0xFF0055A4)),
      ('ES', 'Español', 'es', const Color(0xFFC60B1E)),
    ];
    final currentLocale = Localizations.localeOf(context).languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0820),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (ctx2, scrollCtrl) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.language, color: Colors.white54, size: 32),
            const SizedBox(height: 16),
            Expanded(child: ListView(
              controller: scrollCtrl,
              children: languages.map((lang) {
              final isSelected = currentLocale == lang.$3;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: () {
                    StressCarkiApp.setLocale(context, Locale(lang.$3));
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? lang.$4.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? lang.$4.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: lang.$4.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(lang.$1, style: TextStyle(
                          color: lang.$4,
                          fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1,
                        )),
                      ),
                      const SizedBox(width: 14),
                      Text(lang.$2, style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 16, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                      )),
                      const Spacer(),
                      if (isSelected)
                        Icon(Icons.check_circle, color: lang.$4, size: 22),
                    ]),
                  ),
                ),
              );
            }).toList(),
            )),
          ],
        ),
      ),),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return Dialog(
        backgroundColor: const Color(0xFF0A0820),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFCC3333), Color(0xFF8B0000)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFCC3333).withValues(alpha: 0.3), blurRadius: 20),
                    ],
                  ),
                  child: const Icon(Icons.cyclone, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 18),
                Text(l.aboutTitle, style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 4,
                )),
                const SizedBox(height: 4),
                Text(l.aboutVersion, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12,
                )),
                const SizedBox(height: 24),
                // Açıklama
                Text(
                  l.aboutDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                // Yasal Uyarı başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: const Color(0xFFFF6B6B).withValues(alpha: 0.8), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(l.aboutLegalTitle, style: const TextStyle(
                        color: Color(0xFFFF6B6B), fontSize: 12, fontWeight: FontWeight.w700,
                      ))),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  l.aboutLegalText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5, height: 1.55,
                  ),
                ),
                const SizedBox(height: 20),
                // İletişim
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(l.aboutCopyright, style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4), fontSize: 11, fontWeight: FontWeight.w600,
                      )),
                      const SizedBox(height: 4),
                      Text(l.aboutRights, style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3), fontSize: 10,
                      )),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('https://arslanaytac11-alt.github.io/stress-carki/privacy-policy.html'), mode: LaunchMode.externalApplication),
                            child: Text('Privacy Policy', style: TextStyle(
                              color: const Color(0xFF007AFF), fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF007AFF))),
                          ),
                          Text('  |  ', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 11)),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('https://arslanaytac11-alt.github.io/stress-carki/terms-of-use.html'), mode: LaunchMode.externalApplication),
                            child: Text('Terms of Use', style: TextStyle(
                              color: const Color(0xFF007AFF), fontSize: 11,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color(0xFF007AFF))),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                // Kapat butonu
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFCC3333), Color(0xFF8B0000)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(l.aboutOk, style: const TextStyle(
                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2,
                    )),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  void _pauseEngine() {
    _gameLoop.stop();
    _glowController.stop();
    _physics.angularVelocity = 0;
  }

  void _resumeEngine() {
    if (!mounted) return;
    _gameLoop.forward();
    _glowController.repeat(reverse: true);
  }

  /// Push ile başka ekrana git, dönünce engine'i devam ettir
  void _navigateTo(Widget screen) {
    _pauseEngine();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen)).then((_) {
      _resumeEngine();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _audio.pause();
    } else if (state == AppLifecycleState.resumed) {
      _audio.resume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    GameState.instance.save();
    _gameLoop.dispose();
    _glowController.dispose();
    _gyroSub?.cancel();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _activeSpinner.skin.colors;
    final sz = MediaQuery.of(context).size;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF03020A),
      drawer: _buildDrawer(colors),
      drawerEdgeDragWidth: 40,
      body: Stack(
        children: [
          // ── Galaxy arka plan ──
          RepaintBoundary(
            child: CustomPaint(size: sz, painter: const SpaceBackgroundPainter()),
          ),
          // ── Dinamik renk tint — spinner rengiyle pulse ──
          IgnorePointer(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.8,
                  colors: [
                    colors[0].withValues(alpha: 0.04 + (_rpm / 500 * 0.06).clamp(0.0, 0.06)),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // ── Parçacık katmanı ──
          RepaintBoundary(
            child: CustomPaint(size: sz, painter: ParticlePainter(_particles)),
          ),
          // ── Ana içerik ──
          SafeArea(
            child: Column(
              children: [
                _buildHeader(colors),
                Expanded(child: _buildSpinner(colors)),
                _buildStats(colors),
                _buildBottomBar(colors),
                const BannerAdWidget(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildHeader(List<Color> theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _glassButton(
            child: Icon(Icons.menu_rounded, color: theme[0], size: 20),
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(colors: theme).createShader(r),
                  child: Text(AppLocalizations.of(context)!.appTitle.toUpperCase(), style: const TextStyle(
                    color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w900, letterSpacing: 4,
                  )),
                ),
                const SizedBox(height: 2),
                Text(AppLocalizations.of(context)!.headerSubtitle, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.30),
                  fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w500,
                )),
              ],
            ),
          ),
          // Global RPM badge
          GestureDetector(
            onTap: () => _showBadgesSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    (GameState.instance.currentBadge?.color ?? const Color(0xFFFFD700)).withValues(alpha: 0.15),
                    (GameState.instance.currentBadge?.color ?? const Color(0xFFFFD700)).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: (GameState.instance.currentBadge?.color ?? const Color(0xFFFFD700)).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(GameState.instance.currentBadge?.emoji ?? '🎯', style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 5),
                  Text(GameState.instance.formattedRpm, style: TextStyle(
                    color: GameState.instance.currentBadge?.color ?? const Color(0xFFFFD700),
                    fontSize: 12, fontWeight: FontWeight.w800,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: child,
      ),
    );
  }

  Widget _buildDrawer(List<Color> theme) {
    return Drawer(
      backgroundColor: const Color(0xFF060515),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 14),
            // ── Logo / Başlık ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: theme.map((c) => c.withValues(alpha: 0.15)).toList(),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme[0].withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: theme),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cyclone, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.appTitle.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          foreground: Paint()..shader = LinearGradient(colors: theme)
                              .createShader(const Rect.fromLTWH(0, 0, 150, 20)),
                          fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 2,
                      )),
                      Text('v1.0', style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3), fontSize: 11,
                      )),
                    ],
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Menü öğeleri ──
            Builder(builder: (ctx) {
              final l = AppLocalizations.of(ctx)!;
              return Column(children: [
            _drawerItem(Icons.cyclone, l.menuSpinner, l.menuSpinnerDesc,
                theme[0], true, () => Navigator.pop(context)),
            _drawerItem(Icons.rocket_launch, l.menuOrbit, l.menuOrbitDesc,
                const Color(0xFF00E5FF), false, () {
              Navigator.pop(context);
              _navigateTo(OrbitScreen(spinnerModel: _activeSpinner));
            }),
            _drawerItem(Icons.bolt, l.menuSmash, l.menuSmashDesc,
                const Color(0xFFFF6B6B), false, () {
              Navigator.pop(context);
              _navigateTo(SmashScreen(spinnerModel: _activeSpinner));
            }),
            _drawerItem(Icons.wine_bar, l.menuGlass, l.menuGlassDesc,
                const Color(0xFF80DEEA), false, () {
              Navigator.pop(context);
              _navigateTo(const GlassSmashScreen());
            }),
            _drawerItem(Icons.bubble_chart, l.menuBalloon, l.menuBalloonDesc,
                const Color(0xFFFF8A65), false, () {
              Navigator.pop(context);
              _navigateTo(const BalloonPopScreen());
            }),
            _drawerItem(Icons.sports_handball, l.menuStressBall, l.menuStressBallDesc,
                const Color(0xFF7C4DFF), false, () {
              Navigator.pop(context);
              _navigateTo(const StressBallScreen());
            }),
            _drawerItem(Icons.catching_pokemon, l.menuCollection, l.menuCollectionDesc(SpinnerCollection.all.length),
                theme[1], false, () {
              Navigator.pop(context);
              _pauseEngine();
              _openCollection();
            }),
            _drawerItem(Icons.military_tech, l.menuBadges, l.menuBadgesDesc(GameState.instance.earnedBadges.length, GameState.badges.length),
                const Color(0xFFFFD700), false, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showBadgesSheet();
              });
            }),
            _drawerItem(Icons.air, l.menuBreath, l.menuBreathDesc,
                const Color(0xFF4FC3F7), false, () {
              Navigator.pop(context);
              _navigateTo(const BreathScreen());
            }),
            _drawerItem(
              _audio.isMuted ? Icons.volume_off : Icons.volume_up,
              _audio.isMuted ? l.menuSoundOn : l.menuSoundOff,
              _audio.isMuted ? l.menuSoundDescOff : l.menuSoundDescOn,
              const Color(0xFF9C27B0), false, () {
                _audio.toggleMute();
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) setState(() {});
                });
              },
            ),
            _drawerItem(Icons.language, l.menuLanguage, l.menuLanguageDesc,
                const Color(0xFF26A69A), false, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) _showLanguageDialog();
              });
            }),
            _drawerItem(Icons.info_outline, l.menuAbout, l.menuAboutDesc,
                const Color(0xFF78909C), false, () {
              Navigator.pop(context);
              Future.delayed(const Duration(milliseconds: 400), () {
                if (mounted) _showAboutDialog();
              });
            }),
              ]);
            }),
            const SizedBox(height: 16),
            // ── Rekor gösterimi ──
            Container(
              margin: const EdgeInsets.all(20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppLocalizations.of(context)!.allTimeRecord, style: const TextStyle(
                        color: Color(0xFFFFD700), fontSize: 10, letterSpacing: 1,
                        fontWeight: FontWeight.w600,
                      )),
                      Text('${_allTimeMaxRpm.toStringAsFixed(0)} RPM', style: const TextStyle(
                        color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900,
                      )),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, String subtitle,
      Color color, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: isActive ? Colors.white : Colors.white70,
                  fontSize: 15, fontWeight: FontWeight.w700,
                )),
                Text(subtitle, style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35), fontSize: 11,
                )),
              ],
            ),
            const Spacer(),
            if (isActive)
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              )
            else
              Icon(Icons.chevron_right, color: Colors.white.withValues(alpha: 0.2), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner(List<Color> theme) {
    // Listener kullanarak multi-touch (çift parmak) desteği
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ── Spinner ──
          Center(
            child: AnimatedBuilder(
              animation: _glowController,
              builder: (context, _) {
                final matrix = Matrix4.identity()
                  ..setEntry(3, 2, 0.0008)
                  ..rotateX(_tiltY * 0.25)
                  ..rotateY(_tiltX * 0.25);
                return Transform(
                  transform: matrix,
                  alignment: Alignment.center,
                  child: CustomPaint(
                    key: _spinnerKey,
                    size: const Size(300, 300),
                    painter: SpinnerPainter(
                      angle: _currentAngle,
                      rpm: _rpm,
                      glowIntensity: _rpm > 10 ? _glowAnimation.value : 0.15,
                      primaryColor: theme[0],
                      secondaryColor: theme[1],
                      trailAngles: List.from(_trailAngles),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(List<Color> theme) {
    final level = _getSpeedLevel();
    final progress = (_rpm / 335.0).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          // RPM büyük, MAKS ve SEVİYE küçük
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // RPM
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('RPM', style: TextStyle(
                      color: theme[0].withValues(alpha: 0.7), fontSize: 10,
                      fontWeight: FontWeight.w700, letterSpacing: 2,
                    )),
                    const SizedBox(height: 2),
                    Text(_rpm.toStringAsFixed(0), style: TextStyle(
                      color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900,
                      height: 1.0,
                      shadows: [Shadow(color: theme[0].withValues(alpha: 0.3), blurRadius: 12)],
                    )),
                  ],
                ),
              ),
              // Maks RPM
              _miniStat('MAKS', _maxRpm.toStringAsFixed(0), theme[1]),
              const SizedBox(width: 16),
              // Seviye
              _miniStat(level.label, level.emoji, level.color),
            ],
          ),
          const SizedBox(height: 14),
          // Progress bar — gradient
          Container(
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white.withValues(alpha: 0.04),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        gradient: LinearGradient(colors: [
                          level.color.withValues(alpha: 0.6),
                          level.color,
                        ]),
                        boxShadow: [
                          BoxShadow(color: level.color.withValues(alpha: 0.4), blurRadius: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(level.message, style: TextStyle(
            color: level.color.withValues(alpha: 0.8), fontSize: 13,
            fontWeight: FontWeight.w700, letterSpacing: 1,
          )),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(
          color: color.withValues(alpha: 0.6), fontSize: 9,
          fontWeight: FontWeight.w700, letterSpacing: 1.5,
        )),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w800,
        )),
      ],
    );
  }

  Widget _buildBottomBar(List<Color> theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        children: [
          // Sıfırla — küçük
          _glassButton(
            child: const Icon(Icons.refresh_rounded, color: Colors.white54, size: 20),
            onTap: _resetSession,
          ),
          const SizedBox(width: 10),
          // Çarklar — ana buton
          Expanded(
            child: GestureDetector(
              onTap: _openCollection,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme[0].withValues(alpha: 0.7), theme[1].withValues(alpha: 0.5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: theme[0].withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.catching_pokemon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)?.collectionTitle ?? 'ÇARKLAR', style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800,
                      fontSize: 13, letterSpacing: 2,
                    )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Nefes — küçük
          _glassButton(
            child: const Icon(Icons.air, color: Color(0xFF4FC3F7), size: 20),
            onTap: _openBreathMode,
          ),
        ],
      ),
    );
  }

  SpeedLevel _getSpeedLevel() {
    final l = AppLocalizations.of(context)!;
    if (_rpm < 10) return SpeedLevel('😴', l.speedStop, l.speedStopDesc, const Color(0xFF607D8B));
    if (_rpm < 35) return SpeedLevel('🌿', 'Sakin', 'Rahatla...', const Color(0xFF4CAF50));
    if (_rpm < 80) return SpeedLevel('⚡', l.speedActive, l.speedActiveDesc, const Color(0xFF2196F3));
    if (_rpm < 140) return SpeedLevel('🔥', l.speedFire, l.speedFireDesc, const Color(0xFFFF9800));
    if (_rpm < 220) return SpeedLevel('💥', l.speedCrazy, l.speedCrazyDesc, const Color(0xFFE91E63));
    if (_rpm < 290) return SpeedLevel('🌟', l.speedLegend, l.speedLegendDesc, const Color(0xFFAA00FF));
    return SpeedLevel('👑', 'GOD', '🚀 UNSTOPPABLE 🚀', const Color(0xFFFFD700));
  }
}

class SpeedLevel {
  final String emoji, label, message;
  final Color color;
  SpeedLevel(this.emoji, this.label, this.message, this.color);
}
