import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'physics_engine.dart';
import 'spinner_painter.dart';
import 'l10n/app_localizations.dart';

/// Nefes egzersizi modu
/// Spinner belirli bir ritimde döner, kullanıcı nefes alıp verir
class BreathScreen extends StatefulWidget {
  const BreathScreen({super.key});

  @override
  State<BreathScreen> createState() => _BreathScreenState();
}

class _BreathScreenState extends State<BreathScreen>
    with TickerProviderStateMixin {
  late AnimationController _gameLoop;
  late AnimationController _pulseController;
  late PhysicsEngine _physics;

  // Nefes döngüsü: 4s nefes al, 4s tut, 6s ver (4-4-6 tekniği)
  static const _inhaleTime = 4.0;
  static const _holdTime = 4.0;
  static const _exhaleTime = 6.0;
  static const _totalCycle = _inhaleTime + _holdTime + _exhaleTime;

  double _breathTimer = 0.0;
  BreathPhase _phase = BreathPhase.inhale;
  int _cycleCount = 0;
  bool _running = false;

  double _currentAngle = 0.0;
  double _rpm = 0.0;

  List<String> _getCalmMessages(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return [l.breathQuote1, l.breathQuote2, l.breathQuote3, 'Sadece nefesine odaklan 🌊',
      l.breathQuote4, l.breathQuote5, l.breathQuote6, l.breathQuote7];
  }

  @override
  void initState() {
    super.initState();
    _physics = PhysicsEngine();

    _gameLoop = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_tick);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _gameLoop.forward();
  }

  DateTime _lastTick = DateTime.now();
  void _tick() {
    if (!mounted) return;
    final now = DateTime.now();
    final dt = (now.difference(_lastTick).inMicroseconds / 1e6).clamp(0.001, 0.05);
    _lastTick = now;

    if (_running) {
      _breathTimer += dt;
      if (_breathTimer >= _totalCycle) {
        _breathTimer -= _totalCycle;
        _cycleCount++;
      }

      // Nefes fazını belirle ve hedef RPM ayarla
      final targetRpm = _getTargetRpm();
      final targetVelocity = (targetRpm * 2 * math.pi) / 60.0;
      // Spinner hedef hıza doğru kademeli yaklaş
      _physics.angularVelocity +=
          (targetVelocity - _physics.angularVelocity) * 0.02;
      _physics.angle += _physics.angularVelocity * dt;

      final newPhase = _getPhase();
      if (newPhase != _phase) {
        _phase = newPhase;
      }
    } else {
      _physics.update(dt);
    }

    setState(() {
      _currentAngle = _physics.angle;
      _rpm = _physics.rpm;
    });
  }

  BreathPhase _getPhase() {
    if (_breathTimer < _inhaleTime) return BreathPhase.inhale;
    if (_breathTimer < _inhaleTime + _holdTime) return BreathPhase.hold;
    return BreathPhase.exhale;
  }

  double _getTargetRpm() {
    switch (_getPhase()) {
      case BreathPhase.inhale:
        return 80.0; // Nefes alırken hızlanır
      case BreathPhase.hold:
        return 120.0; // Tutarken max hız
      case BreathPhase.exhale:
        return 30.0; // Nefes verirken yavaşlar
    }
  }

  double _getPhaseProgress() {
    switch (_phase) {
      case BreathPhase.inhale:
        return _breathTimer / _inhaleTime;
      case BreathPhase.hold:
        return (_breathTimer - _inhaleTime) / _holdTime;
      case BreathPhase.exhale:
        return (_breathTimer - _inhaleTime - _holdTime) / _exhaleTime;
    }
  }

  @override
  void dispose() {
    _gameLoop.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context),
            Expanded(child: _buildMain()),
            _buildControls(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            AppLocalizations.of(context)?.menuBreath.toUpperCase() ?? 'NEFES MODU',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          if (_cycleCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                AppLocalizations.of(context)!.breathCycles(_cycleCount),
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMain() {
    final phaseInfo = _getPhaseInfo();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Nefes göstergesi — dışarı yayılan halka
        if (_running)
          AnimatedBuilder(
            animation: _pulseController,
            builder: (_, _) {
              final progress = _getPhaseProgress();
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Dış halka — nefes büyüklüğü
                  Container(
                    width: 340 * (0.7 + progress * 0.3),
                    height: 340 * (0.7 + progress * 0.3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: phaseInfo.color.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                  ),
                  // Spinner
                  CustomPaint(
                    size: const Size(280, 280),
                    painter: SpinnerPainter(
                      angle: _currentAngle,
                      rpm: _rpm,
                      glowIntensity: 0.7,
                      primaryColor: phaseInfo.color,
                      secondaryColor:
                          Color.lerp(phaseInfo.color, Colors.white, 0.3)!,
                    ),
                  ),
                ],
              );
            },
          )
        else
          CustomPaint(
            size: const Size(280, 280),
            painter: SpinnerPainter(
              angle: _currentAngle,
              rpm: _rpm,
              glowIntensity: 0.3,
              primaryColor: const Color(0xFF4FC3F7),
              secondaryColor: const Color(0xFF0288D1),
            ),
          ),

        const SizedBox(height: 32),

        // Faz metni
        if (_running) ...[
          Text(
            phaseInfo.label,
            style: TextStyle(
              color: phaseInfo.color,
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            phaseInfo.instruction,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          // İlerleme çubuğu
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _getPhaseProgress(),
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(phaseInfo.color),
              ),
            ),
          ),

          // Motivasyon mesajı
          if (_cycleCount > 0) ...[
            const SizedBox(height: 16),
            Text(
              _getCalmMessages(context)[_cycleCount % 8],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ] else ...[
          Text(
            AppLocalizations.of(context)!.breathReady,
            style: const TextStyle(
                color: Colors.white60, fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          const Text(
            '4s nefes al · 4s tut · 6s nefes ver',
            style: TextStyle(color: Colors.white30, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)!.breathInstruction,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }

  _PhaseInfo _getPhaseInfo() {
    switch (_phase) {
      case BreathPhase.inhale:
        return _PhaseInfo(
          label: 'NEFES AL',
          instruction: AppLocalizations.of(context)!.breathInhale,
          color: const Color(0xFF4FC3F7),
        );
      case BreathPhase.hold:
        return _PhaseInfo(
          label: 'TUT',
          instruction: 'Hold',
          color: const Color(0xFFB39DDB),
        );
      case BreathPhase.exhale:
        return _PhaseInfo(
          label: 'NEFES VER',
          instruction: AppLocalizations.of(context)!.breathExhale,
          color: const Color(0xFF80CBC4),
        );
    }
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: GestureDetector(
        onTap: () => setState(() {
          _running = !_running;
          if (_running) _breathTimer = 0;
        }),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _running
                  ? [Colors.red.shade900, Colors.red.shade700]
                  : [const Color(0xFF4FC3F7), const Color(0xFF0288D1)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_running ? Icons.stop : Icons.play_arrow,
                  color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(
                _running ? AppLocalizations.of(context)!.breathStop : AppLocalizations.of(context)!.breathStart,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum BreathPhase { inhale, hold, exhale }

class _PhaseInfo {
  final String label, instruction;
  final Color color;
  _PhaseInfo({required this.label, required this.instruction, required this.color});
}
