import 'package:flutter/services.dart';

/// Gelişmiş ses & haptic motoru — her mod için özel feedback desenleri
class SoundEngine {
  int _tickCounter = 0;

  /// Spinner modu — RPM'e göre titreşim ritmi
  void update(double rpm) {
    if (rpm < 5) {
      _tickCounter = 0;
      return;
    }
    _tickCounter++;
    final tickInterval = _getTickInterval(rpm);
    if (_tickCounter >= tickInterval) {
      _tickCounter = 0;
      _triggerFeedback(rpm);
    }
  }

  int _getTickInterval(double rpm) {
    if (rpm < 50) return 45;
    if (rpm < 100) return 25;
    if (rpm < 200) return 12;
    if (rpm < 300) return 6;
    return 3;
  }

  void _triggerFeedback(double rpm) {
    if (rpm < 100) {
      HapticFeedback.selectionClick();
    } else if (rpm < 250) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  // ═══════════════════════════════════════════
  //  MOD-BAZLI HAPTİC FEEDBACK
  // ═══════════════════════════════════════════

  /// Cam kırma — vuruş şiddeti
  static void glassHit({double damage = 0}) {
    if (damage > 0.7) {
      HapticFeedback.heavyImpact();
    } else if (damage > 0.3) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Cam tamamen kırıldı — ağır çift titreşim
  static void glassShatter() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 80), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// Balon patladı — tipi'ne göre
  static void balloonPop({bool isGold = false, bool isIce = false, int combo = 0}) {
    if (isGold) {
      // Altın balon — güçlü çift titreşim
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.mediumImpact();
      });
    } else if (isIce) {
      // Buz balon — hafif crispy feedback
      HapticFeedback.selectionClick();
      Future.delayed(const Duration(milliseconds: 30), () {
        HapticFeedback.selectionClick();
      });
    } else if (combo >= 5) {
      // Yüksek combo — heavy
      HapticFeedback.heavyImpact();
    } else if (combo >= 3) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Balon kaçırdı — uyarı titreşimi
  static void balloonMiss() {
    HapticFeedback.heavyImpact();
  }

  /// Seviye atladı — kutlama titreşimi
  static void levelUp() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.lightImpact();
    });
  }

  /// Stres topu sıkma — basınca göre
  static void stressBallSqueeze({double pressure = 0.5}) {
    if (pressure > 0.7) {
      HapticFeedback.mediumImpact();
    } else if (pressure > 0.3) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  /// Stres topu fırlattı
  static void stressBallFling() {
    HapticFeedback.mediumImpact();
  }

  /// Stres topu duvara çarptı
  static void stressBallBounce() {
    HapticFeedback.lightImpact();
  }

  /// Parçalama modu — vuruş
  static void smashHit({double intensity = 0.5}) {
    if (intensity > 0.7) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// Orbit modu — tur tamamladı
  static void orbitSpin() {
    HapticFeedback.selectionClick();
  }

  /// Rozet kazanıldı
  static void badgeEarned() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      HapticFeedback.mediumImpact();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      HapticFeedback.heavyImpact();
    });
  }

  /// UI buton tıklama
  static void uiTap() {
    HapticFeedback.selectionClick();
  }

  /// Game over
  static void gameOver() {
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 350), () {
      HapticFeedback.mediumImpact();
    });
  }
}
