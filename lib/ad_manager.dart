import 'dart:io';

/// AdMob Reklam Yöneticisi
/// Test ID'leri kullanır — production'da gerçek ID'lere değiştir.
class AdManager {
  AdManager._();
  static final instance = AdManager._();

  bool _initialized = false;
  int _screenChangeCount = 0;
  static const int _adFrequency = 3; // Her 3 ekran geçişinde 1 reklam

  // ── Test ID'leri (Google'ın resmi test ID'leri) ──
  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713'; // Android test
    } else {
      return 'ca-app-pub-3940256099942544~1458002511'; // iOS test
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial
    } else {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS test interstitial
    }
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android test rewarded
    } else {
      return 'ca-app-pub-3940256099942544/1712485313'; // iOS test rewarded
    }
  }

  /// AdMob başlat
  Future<void> initialize() async {
    if (_initialized) return;
    // google_mobile_ads paketi eklendiğinde:
    // await MobileAds.instance.initialize();
    _initialized = true;
  }

  /// Ekran geçişi sayacı — her N geçişte reklam göster
  bool shouldShowInterstitial() {
    _screenChangeCount++;
    if (_screenChangeCount >= _adFrequency) {
      _screenChangeCount = 0;
      return true;
    }
    return false;
  }

  /// Sayacı sıfırla
  void resetCounter() {
    _screenChangeCount = 0;
  }
}
