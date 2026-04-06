import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob Reklam Yoneticisi
/// Production'da gercek ID'lere degistir.
class AdManager {
  AdManager._();
  static final instance = AdManager._();

  bool _initialized = false;
  int _screenChangeCount = 0;
  static const int _adFrequency = 3; // Her 3 ekran gecisinde 1 reklam

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  // ══════════════════════════════════════════════════════════════
  //  AD UNIT ID'LERI
  //  TODO: Production'da asagidaki test ID'lerini gercek ID'lere degistir
  // ══════════════════════════════════════════════════════════════

  static String get appId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544~3347511713'; // Android test
    } else {
      return 'ca-app-pub-9257944510825127~6374451247'; // iOS gercek
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android test interstitial
    } else {
      return 'ca-app-pub-9257944510825127/5735119589'; // iOS gercek
    }
  }

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android test banner
    } else {
      return 'ca-app-pub-9257944510825127/9718799880'; // iOS gercek
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Android test rewarded
    } else {
      return ''; // Rewarded kullanilmiyor
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  BASLAT
  // ══════════════════════════════════════════════════════════════

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    // Cocuklara uygun reklam icerigi (4+ yas derecesi icin)
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        maxAdContentRating: MaxAdContentRating.g,
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.yes,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.yes,
      ),
    );
    _initialized = true;
    _loadInterstitialAd();
    _loadRewardedAd();
  }

  // ══════════════════════════════════════════════════════════════
  //  INTERSTITIAL (Gecis Reklamlari)
  // ══════════════════════════════════════════════════════════════

  void _loadInterstitialAd() {
    if (_isInterstitialLoading || _interstitialAd != null) return;
    _isInterstitialLoading = true;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialLoading = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd(); // Yenisini yukle
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          _isInterstitialLoading = false;
          // 30sn sonra tekrar dene
          Future.delayed(const Duration(seconds: 30), _loadInterstitialAd);
        },
      ),
    );
  }

  /// Ekran gecisi sayacini artir, gerekirse reklam goster
  bool shouldShowInterstitial() {
    _screenChangeCount++;
    if (_screenChangeCount >= _adFrequency) {
      _screenChangeCount = 0;
      return true;
    }
    return false;
  }

  /// Interstitial reklami goster
  Future<bool> showInterstitial() async {
    if (_interstitialAd == null) {
      _loadInterstitialAd();
      return false;
    }
    await _interstitialAd!.show();
    return true;
  }

  /// Ekran gecislerinde otomatik reklam kontrolu
  void onScreenChange() {
    if (shouldShowInterstitial()) {
      showInterstitial();
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  REWARDED (Odullu Reklamlar)
  // ══════════════════════════════════════════════════════════════

  void _loadRewardedAd() {
    if (rewardedAdUnitId.isEmpty) return; // iOS'ta rewarded yok
    if (_isRewardedLoading || _rewardedAd != null) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _isRewardedLoading = false;
          Future.delayed(const Duration(seconds: 30), _loadRewardedAd);
        },
      ),
    );
  }

  /// Rewarded reklam hazir mi?
  bool get isRewardedReady => _rewardedAd != null;

  /// Rewarded reklami goster, odul callback'i ile
  Future<bool> showRewarded({required void Function(RewardItem reward) onRewarded}) async {
    if (rewardedAdUnitId.isEmpty || _rewardedAd == null) {
      _loadRewardedAd();
      return false;
    }
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        _loadRewardedAd();
      },
    );
    await _rewardedAd!.show(onUserEarnedReward: (_, reward) {
      onRewarded(reward);
    });
    return true;
  }

  /// Sayaci sifirla
  void resetCounter() {
    _screenChangeCount = 0;
  }

  /// Tum reklamlari temizle
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}

// ══════════════════════════════════════════════════════════════
//  BANNER AD WIDGET — Herhangi bir ekranin altina eklenebilir
// ══════════════════════════════════════════════════════════════

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bannerAd == null) _loadAd();
  }

  void _loadAd() {
    final adSize = AdSize.banner;
    _bannerAd = BannerAd(
      adUnitId: AdManager.bannerAdUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          // 30sn sonra tekrar dene
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadAd();
          });
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) return const SizedBox.shrink();
    return Container(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
