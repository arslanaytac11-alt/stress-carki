# Stres Çarkı - Flutter Fidget Spinner Stress Relief App

## Proje Özeti
50M+ indirme hedefli mobil stres atma uygulaması. Spinner döndürme, cam kırma, balon patlatma, stres topu, parçalama, uzay orbit ve nefes egzersizi modları içerir.

## Build & Install Komutları
```
# Build APK
powershell.exe -Command "Set-Location 'C:\Users\User\Desktop\stress_carki_flutter'; C:\Users\User\flutter\bin\flutter.bat build apk --debug 2>&1"

# Install APK (telefon bağlı olmalı)
powershell.exe -Command "& 'C:\Users\User\AppData\Local\Android\Sdk\platform-tools\adb.exe' install -r 'C:\Users\User\Desktop\stress_carki_flutter\build\app\outputs\flutter-apk\app-debug.apk' 2>&1"

# Disk dolunca
flutter clean && flutter pub get && flutter build apk --debug

# Lokalizasyon dosyalarını yeniden oluştur
flutter gen-l10n
```

## Dosya Yapısı

### Ana Dosyalar
- `lib/main.dart` — App entry, locale yönetimi, StressCarkiApp.setLocale()
- `lib/home_screen.dart` — Ana menü ekranı (splash sonrası), dil seçimi (bayrak emoji yerine renkli badge)
- `lib/splash_screen.dart` — Açılış splash ekranı (kırmızı cyclone)
- `lib/game_state.dart` — Singleton GameState, RPM, rozetler, SharedPreferences

### Oyun Modları
- `lib/spinner_screen.dart` — Ana spinner modu + drawer menü
- `lib/smash_screen.dart` — Parçalama modu (vur ve kır)
- `lib/glass_smash_screen.dart` — Cam kırma modu (bardak, şişe, vazo, damacana, tabak)
- `lib/balloon_pop_screen.dart` — Balon patlatma (3 tip, combo, 3 can, seviye sistemi)
- `lib/stress_ball_screen.dart` — Stres topu (mesh deformasyon, sürükle/fırlat, sıkma)
- `lib/orbit_screen.dart` — Uzay orbit modu
- `lib/breath_screen.dart` — Nefes egzersizi modu
- `lib/collection_screen.dart` — Koleksiyon/rozet ekranı
- `lib/stats_screen.dart` — İstatistik sayfası

### Motor & Sistem
- `lib/audio_engine.dart` — Ses motoru
- `lib/sound_engine.dart` — Gelişmiş haptic feedback motoru (mod bazlı titreşim desenleri)
- `lib/physics_engine.dart` — Fizik motoru
- `lib/combo_system.dart` — Combo sistemi
- `lib/ad_manager.dart` — AdMob reklam yöneticisi (test ID'leri, interstitial/banner/rewarded)

### Grafikler
- `lib/spinner_painter.dart` — Spinner CustomPainter
- `lib/particle_painter.dart` — Parçacık efektleri
- `lib/quote_arc_painter.dart` — Yazı arc painter
- `lib/space_background_painter.dart` — Uzay arka plan
- `lib/spinner_collection.dart` — Spinner koleksiyonu

### Lokalizasyon (5 dil: TR, EN, DE, FR, ES)
- `lib/l10n/app_tr.arb` — Türkçe (ana dil)
- `lib/l10n/app_en.arb` — İngilizce
- `lib/l10n/app_de.arb` — Almanca
- `lib/l10n/app_fr.arb` — Fransızca
- `lib/l10n/app_es.arb` — İspanyolca
- `lib/l10n/app_localizations.dart` — Generated base class
- `lib/l10n/app_localizations_*.dart` — Generated locale implementations

## Teknik Mimari
- **State**: Singleton `GameState.instance` + SharedPreferences
- **Rendering**: CustomPaint + RepaintBoundary
- **Game Loop**: AnimationController(duration: Duration(days:1)) + delta-time
- **Physics**: DateTime.now() farkı ile gerçek frame timing (dt clamped 0.001-0.05)
- **Localization**: Flutter l10n (ARB + gen-l10n + AppLocalizations)
- **Dil Değiştirme**: StressCarkiApp.setLocale() + SharedPreferences 'app_language'
- **RPM Sistemi**: GameState.addRpm() → List<Badge> döner (çoklu rozet desteği)
- **Rozet İsimleri**: localizedBadgeName() helper ile çeviri
- **Haptic**: SoundEngine sınıfı — her mod için özel titreşim desenleri
- **Reklam**: AdManager singleton — test ID'leri hazır, google_mobile_ads paketi eklendiğinde aktif

## Yapılan İyileştirmeler (Geçmiş)
- [x] RPM kazanımı tüm modlarda çalışıyor
- [x] 5 dil desteği (TR, EN, DE, FR, ES) + runtime değiştirme
- [x] Uygulama adı ve başlık dile göre değişiyor
- [x] SharedPreferences nullable yapıldı (crash fix)
- [x] RepaintBoundary eklendi (performans)
- [x] Debris listesi 300'de cap'lendi (bellek)
- [x] Overlay leak düzeltildi (mounted check)
- [x] Gerçek frame timing tüm ekranlarda (dt fix)
- [x] Multi-badge desteği (addRpm List<Badge> döner)
- [x] Cam kırma objesi HP'den başlatılıyor
- [x] Balon patlatma modu eklendi (premium efektler, seviye sistemi)
- [x] Stres topu modu eklendi (mesh deformasyon, jelly physics)
- [x] Ana menü ekranı eklendi (home_screen.dart)
- [x] Immersive mode (navigasyon çubuğu gizleme)
- [x] Uygulama ikonu kırmızı cyclone
- [x] Splash ekranı kırmızı gradient
- [x] Dil seçimi bayrak emoji yerine renkli badge (Samsung uyumluluk)
- [x] Rozet listesi scrollable (overflow fix)
- [x] Balon sınır kontrolü (yandan çıkmıyor)
- [x] SoundEngine — mod bazlı haptic feedback (cam/balon/top/orbit/rozet/UI)
- [x] AdManager — test ID'leriyle reklam altyapısı hazır

## Bilinen Sorunlar / Yapılacaklar
- [ ] Spinner fiziği: basılı tutunca dursun, yavaş yavaş hızlansın, ekran değişince dursun
- [ ] Rozet animasyonu bozuk — düzeltilmeli
- [ ] Müzik arka planda durmuyor — lifecycle yönetimi eksik
- [ ] AdMob gerçek ID'leri girilecek (kullanıcıdan bekleniyor)
- [ ] google_mobile_ads paketi eklenecek
- [ ] Premium temalar (neon, pastel, galaksi)
- [ ] Günlük görevler sistemi
- [ ] Seviye/XP sistemi

## Önemli Notlar
- Glass object isimleri İngilizce key olarak saklanır: 'glass', 'bottle', 'vase', 'jug', 'plate' → _localizedGlassName() ile çevrilir
- Dil seçimi renkli badge'ler kullanır (bayrak emojileri Samsung'da bozuk)
- Balon modunda 3 can, 3 tip balon (normal, gold 5x, ice slow-mo), 30sn'de seviye atlar
- Stres topu: kısa basma=sıkma, sürükleme=hareket, bırakınca fırlatma
- Global leaderboard iptal edildi — sadece local
- AdMob test ID'leri Google'ın resmi test ID'leri — production'da değiştirilmeli
