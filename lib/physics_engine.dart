import 'dart:math' as math;

/// Fidget spinner fiziği — gerçekçi ataleti, kademeli hızlanma, basılı tutma freni.
class PhysicsEngine {
  double angularVelocity = 0.0;
  double angle = 0.0;

  // ── Sürtünme ──
  static const double _freeFriction = 0.9975;   // serbest dönüş sürtünmesi
  static const double _gripFriction = 0.96;      // basılı tutarken güçlü fren
  static const double _airDragCoeff = 0.00006;
  static const double _maxVelocity = 80.0;       // ~764 RPM

  // ── Sürükleme — kademeli hızlanma ──
  static const double _swipeDeadzone = 0.3;
  double _swipeMomentum = 0.0;   // biriken sürükleme gücü (kademeli artar)
  static const double _momentumBuildRate = 2.5;  // momentum artış hızı (saniye)
  static const double _maxMomentum = 1.0;        // max momentum çarpanı

  // ── Flik ──
  double _flickBoostRemaining = 0.0;
  double _flickBoostPerSec = 0.0;
  static const double _flickRampTime = 0.22;

  // ── Durum ──
  bool _isTouching = false;
  bool _isDragging = false;      // aktif sürükleme var mı
  double _touchDuration = 0.0;   // ne kadar süredir basılı

  double get rpm => (angularVelocity.abs() * 60) / (2 * math.pi);

  void update(double dt) {
    // ── Basılı tutma süresi ──
    if (_isTouching) {
      _touchDuration += dt;
    }

    // ── Flik boost (rampa) ──
    if (_flickBoostRemaining.abs() > 0.002) {
      final apply = _flickBoostPerSec * dt;
      if (apply.abs() > _flickBoostRemaining.abs()) {
        angularVelocity += _flickBoostRemaining;
        _flickBoostRemaining = 0.0;
      } else {
        angularVelocity += apply;
        _flickBoostRemaining -= apply;
      }
    } else {
      _flickBoostRemaining = 0.0;
    }

    // ── Açı güncelle ──
    angle += angularVelocity * dt;

    // ── Sürtünme ──
    if (_isTouching && !_isDragging) {
      // BASILI TUTUYOR ama sürüklemiyor → fren (gerçek spinner gibi)
      angularVelocity *= math.pow(_gripFriction, dt * 60).toDouble();
    } else if (!_isTouching) {
      // Serbest dönüş — uzun momentum
      angularVelocity *= math.pow(_freeFriction, dt * 60).toDouble();
      final drag = _airDragCoeff * angularVelocity * angularVelocity.abs();
      angularVelocity -= drag * dt * 60;
    }
    // Sürüklüyorken minimal sürtünme (parmak kontrol ediyor)

    // Sürükleme bittiğini takip et
    _isDragging = false;

    if (angularVelocity.abs() < 0.005) angularVelocity = 0.0;
    angularVelocity = angularVelocity.clamp(-_maxVelocity, _maxVelocity);
  }

  /// Sürükleme — kademeli hızlanma (ataleti simüle)
  void applySwipe(double fingerVelocity, double dt) {
    if (fingerVelocity.abs() < _swipeDeadzone) return;
    _isDragging = true;

    // Momentum kademeli olarak artar — ilk saniye yavaş, sonra güçlenir
    _swipeMomentum = (_swipeMomentum + dt * _momentumBuildRate)
        .clamp(0.0, _maxMomentum);

    // Düşük momentum = yavaş başlangıç, yüksek momentum = tam güç
    // ease-in eğrisi: momentum² → ilk anlar çok yavaş
    final eased = _swipeMomentum * _swipeMomentum;

    final sameDir = angularVelocity == 0.0 ||
        (fingerVelocity > 0) == (angularVelocity > 0);

    double gain = 0.45 * eased;  // base gain × eased momentum
    if (sameDir) {
      final speedRatio = angularVelocity.abs() / _maxVelocity;
      gain *= (1.0 - speedRatio * 0.6);
    } else {
      gain *= 1.3;
    }

    angularVelocity += fingerVelocity * gain * dt.clamp(0.005, 0.05) * 20;
    angularVelocity = angularVelocity.clamp(-_maxVelocity, _maxVelocity);
  }

  /// Flik — parmak bırakma, hız patlaması
  void applyFlick(double releaseVelocity) {
    _isTouching = false;
    _isDragging = false;
    _swipeMomentum = 0.0;
    _touchDuration = 0.0;

    if (releaseVelocity.abs() < 0.8) return;

    final clamped = releaseVelocity.clamp(-25.0, 25.0);
    final sameDir = angularVelocity == 0.0 ||
        (clamped > 0) == (angularVelocity > 0);

    double boost;
    if (!sameDir) {
      boost = clamped * 0.4;
    } else {
      final headroom = (_maxVelocity - angularVelocity.abs()) / _maxVelocity;
      final efficiency = 0.3 + headroom * 0.7;
      boost = clamped * 1.8 * efficiency;
    }

    _flickBoostRemaining += boost;
    _flickBoostPerSec = _flickBoostRemaining / _flickRampTime;
  }

  /// Grip — parmak dokundu
  void applyGrip() {
    _isTouching = true;
    _isDragging = false;
    _swipeMomentum = 0.0;
    _touchDuration = 0.0;
    // Flik boostunu iptal et — parmak bastı, kontrol alıyor
    _flickBoostRemaining = 0.0;
    _flickBoostPerSec = 0.0;
  }

  /// Parmak kalktı (fliksiz)
  void releaseFinger() {
    _isTouching = false;
    _isDragging = false;
    _swipeMomentum = 0.0;
    _touchDuration = 0.0;
  }
}
