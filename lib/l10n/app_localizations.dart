import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('tr'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In tr, this message translates to:
  /// **'Stres Çarkı'**
  String get appTitle;

  /// No description provided for @splashTagline.
  ///
  /// In tr, this message translates to:
  /// **'Döndür  ·  Kır  ·  Rahatla'**
  String get splashTagline;

  /// No description provided for @menuSpinner.
  ///
  /// In tr, this message translates to:
  /// **'Spinner Modu'**
  String get menuSpinner;

  /// No description provided for @menuSpinnerDesc.
  ///
  /// In tr, this message translates to:
  /// **'Klasik döndürme'**
  String get menuSpinnerDesc;

  /// No description provided for @menuOrbit.
  ///
  /// In tr, this message translates to:
  /// **'Uzay Orbit'**
  String get menuOrbit;

  /// No description provided for @menuOrbitDesc.
  ///
  /// In tr, this message translates to:
  /// **'Uzayda dön!'**
  String get menuOrbitDesc;

  /// No description provided for @menuSmash.
  ///
  /// In tr, this message translates to:
  /// **'Parçala'**
  String get menuSmash;

  /// No description provided for @menuSmashDesc.
  ///
  /// In tr, this message translates to:
  /// **'Vur ve parçala!'**
  String get menuSmashDesc;

  /// No description provided for @menuGlass.
  ///
  /// In tr, this message translates to:
  /// **'Cam Kırma'**
  String get menuGlass;

  /// No description provided for @menuGlassDesc.
  ///
  /// In tr, this message translates to:
  /// **'Kır ve rahatla!'**
  String get menuGlassDesc;

  /// No description provided for @menuCollection.
  ///
  /// In tr, this message translates to:
  /// **'Çark Koleksiyonu'**
  String get menuCollection;

  /// No description provided for @menuCollectionDesc.
  ///
  /// In tr, this message translates to:
  /// **'{count} çark'**
  String menuCollectionDesc(int count);

  /// No description provided for @menuBadges.
  ///
  /// In tr, this message translates to:
  /// **'Rozetlerim'**
  String get menuBadges;

  /// No description provided for @menuBadgesDesc.
  ///
  /// In tr, this message translates to:
  /// **'{earned}/{total} rozet'**
  String menuBadgesDesc(int earned, int total);

  /// No description provided for @menuBreath.
  ///
  /// In tr, this message translates to:
  /// **'Nefes Modu'**
  String get menuBreath;

  /// No description provided for @menuBreathDesc.
  ///
  /// In tr, this message translates to:
  /// **'Rahatlama'**
  String get menuBreathDesc;

  /// No description provided for @menuSoundOn.
  ///
  /// In tr, this message translates to:
  /// **'Sesi Aç'**
  String get menuSoundOn;

  /// No description provided for @menuSoundOff.
  ///
  /// In tr, this message translates to:
  /// **'Sesi Kapat'**
  String get menuSoundOff;

  /// No description provided for @menuSoundDescOn.
  ///
  /// In tr, this message translates to:
  /// **'Müzik açık'**
  String get menuSoundDescOn;

  /// No description provided for @menuSoundDescOff.
  ///
  /// In tr, this message translates to:
  /// **'Müzik kapalı'**
  String get menuSoundDescOff;

  /// No description provided for @menuAbout.
  ///
  /// In tr, this message translates to:
  /// **'Hakkında'**
  String get menuAbout;

  /// No description provided for @menuAboutDesc.
  ///
  /// In tr, this message translates to:
  /// **'Yasal bilgi & versiyon'**
  String get menuAboutDesc;

  /// No description provided for @menuLanguage.
  ///
  /// In tr, this message translates to:
  /// **'Dil'**
  String get menuLanguage;

  /// No description provided for @menuLanguageDesc.
  ///
  /// In tr, this message translates to:
  /// **'Dil değiştir'**
  String get menuLanguageDesc;

  /// No description provided for @headerSubtitle.
  ///
  /// In tr, this message translates to:
  /// **'Döndür & Rahatla'**
  String get headerSubtitle;

  /// No description provided for @allTimeRecord.
  ///
  /// In tr, this message translates to:
  /// **'TÜM ZAMANLARIN REKORU'**
  String get allTimeRecord;

  /// No description provided for @speedStop.
  ///
  /// In tr, this message translates to:
  /// **'Dur'**
  String get speedStop;

  /// No description provided for @speedStopDesc.
  ///
  /// In tr, this message translates to:
  /// **'Döndürmeye başla!'**
  String get speedStopDesc;

  /// No description provided for @speedActive.
  ///
  /// In tr, this message translates to:
  /// **'Aktif'**
  String get speedActive;

  /// No description provided for @speedActiveDesc.
  ///
  /// In tr, this message translates to:
  /// **'Güzel gidiyor!'**
  String get speedActiveDesc;

  /// No description provided for @speedFire.
  ///
  /// In tr, this message translates to:
  /// **'Ateşli'**
  String get speedFire;

  /// No description provided for @speedFireDesc.
  ///
  /// In tr, this message translates to:
  /// **'Stres uçuyor!'**
  String get speedFireDesc;

  /// No description provided for @speedCrazy.
  ///
  /// In tr, this message translates to:
  /// **'ÇILGIN'**
  String get speedCrazy;

  /// No description provided for @speedCrazyDesc.
  ///
  /// In tr, this message translates to:
  /// **'DEVAM ET!!'**
  String get speedCrazyDesc;

  /// No description provided for @speedLegend.
  ///
  /// In tr, this message translates to:
  /// **'EFSANE'**
  String get speedLegend;

  /// No description provided for @speedLegendDesc.
  ///
  /// In tr, this message translates to:
  /// **'İNANILMAZ!!!'**
  String get speedLegendDesc;

  /// No description provided for @badgesTitle.
  ///
  /// In tr, this message translates to:
  /// **'ROZETLERİM'**
  String get badgesTitle;

  /// No description provided for @badgesTotal.
  ///
  /// In tr, this message translates to:
  /// **'Toplam: {rpm} RPM'**
  String badgesTotal(String rpm);

  /// No description provided for @newBadge.
  ///
  /// In tr, this message translates to:
  /// **'YENİ ROZET!'**
  String get newBadge;

  /// No description provided for @badgeBaslangic.
  ///
  /// In tr, this message translates to:
  /// **'Başlangıç'**
  String get badgeBaslangic;

  /// No description provided for @badgeCaylak.
  ///
  /// In tr, this message translates to:
  /// **'Çaylak'**
  String get badgeCaylak;

  /// No description provided for @badgeMerakli.
  ///
  /// In tr, this message translates to:
  /// **'Meraklı'**
  String get badgeMerakli;

  /// No description provided for @badgeSporcu.
  ///
  /// In tr, this message translates to:
  /// **'Sporcu'**
  String get badgeSporcu;

  /// No description provided for @badgeAzimli.
  ///
  /// In tr, this message translates to:
  /// **'Azimli'**
  String get badgeAzimli;

  /// No description provided for @badgeUsta.
  ///
  /// In tr, this message translates to:
  /// **'Usta'**
  String get badgeUsta;

  /// No description provided for @badgeUzman.
  ///
  /// In tr, this message translates to:
  /// **'Uzman'**
  String get badgeUzman;

  /// No description provided for @badgeEfsane.
  ///
  /// In tr, this message translates to:
  /// **'Efsane'**
  String get badgeEfsane;

  /// No description provided for @badgeSampiyon.
  ///
  /// In tr, this message translates to:
  /// **'Şampiyon'**
  String get badgeSampiyon;

  /// No description provided for @badgeElmas.
  ///
  /// In tr, this message translates to:
  /// **'Elmas'**
  String get badgeElmas;

  /// No description provided for @badgeTanri.
  ///
  /// In tr, this message translates to:
  /// **'Tanrı'**
  String get badgeTanri;

  /// No description provided for @badgeGalaktik.
  ///
  /// In tr, this message translates to:
  /// **'Galaktik'**
  String get badgeGalaktik;

  /// No description provided for @badgeEvrensel.
  ///
  /// In tr, this message translates to:
  /// **'Evrensel'**
  String get badgeEvrensel;

  /// No description provided for @badgeSonsuz.
  ///
  /// In tr, this message translates to:
  /// **'Sonsuz'**
  String get badgeSonsuz;

  /// No description provided for @aboutTitle.
  ///
  /// In tr, this message translates to:
  /// **'STRES ÇARKI'**
  String get aboutTitle;

  /// No description provided for @aboutVersion.
  ///
  /// In tr, this message translates to:
  /// **'Versiyon 1.0.0'**
  String get aboutVersion;

  /// No description provided for @aboutDescription.
  ///
  /// In tr, this message translates to:
  /// **'Stres Çarkı, günlük hayatın yoğunluğunda zihinsel rahatlama sağlamak amacıyla tasarlanmış bir eğlence uygulamasıdır. Sanal fidget spinner deneyimi, nefes egzersizleri ve stres atma modları ile keyifli vakit geçirmenizi sağlar.'**
  String get aboutDescription;

  /// No description provided for @aboutLegalTitle.
  ///
  /// In tr, this message translates to:
  /// **'Yasal Uyarı ve Sorumluluk Reddi'**
  String get aboutLegalTitle;

  /// No description provided for @aboutLegalText.
  ///
  /// In tr, this message translates to:
  /// **'• Bu uygulama yalnızca eğlence amaçlıdır. Tıbbi, psikolojik veya terapötik bir tedavi aracı değildir.\n\n• Uygulama içerisindeki nefes egzersizleri ve rahatlama modları profesyonel sağlık hizmeti yerine geçmez. Herhangi bir sağlık sorununuz varsa lütfen bir uzmana başvurunuz.\n\n• Uygulamanın kullanımından doğabilecek doğrudan veya dolaylı hiçbir zarardan geliştiriciler sorumlu tutulamaz.\n\n• Uygulama \"olduğu gibi\" sunulmaktadır; herhangi bir garanti verilmemektedir.\n\n• Uzun süreli kullanımda göz yorgunluğu veya baş dönmesi yaşanabilir. Bu gibi durumlarda kullanımı durdurunuz.\n\n• Epilepsi hastalarının titreşim ve hızlı hareket eden görseller içerdiğinden dikkatli kullanmaları önerilir.\n\n• Kullanıcı, uygulamayı indirip kullanarak bu şartları kabul etmiş sayılır.'**
  String get aboutLegalText;

  /// No description provided for @aboutCopyright.
  ///
  /// In tr, this message translates to:
  /// **'© 2025 Stres Çarkı'**
  String get aboutCopyright;

  /// No description provided for @aboutRights.
  ///
  /// In tr, this message translates to:
  /// **'Tüm hakları saklıdır.'**
  String get aboutRights;

  /// No description provided for @aboutOk.
  ///
  /// In tr, this message translates to:
  /// **'TAMAM'**
  String get aboutOk;

  /// No description provided for @breathCycles.
  ///
  /// In tr, this message translates to:
  /// **'{count} döngü'**
  String breathCycles(int count);

  /// No description provided for @breathReady.
  ///
  /// In tr, this message translates to:
  /// **'Hazır mısın?'**
  String get breathReady;

  /// No description provided for @breathInstruction.
  ///
  /// In tr, this message translates to:
  /// **'Gözlerini kapat, çarkı takip et\nve stresten kurtul'**
  String get breathInstruction;

  /// No description provided for @breathInhale.
  ///
  /// In tr, this message translates to:
  /// **'Yavaşça burnundan nefes al'**
  String get breathInhale;

  /// No description provided for @breathExhale.
  ///
  /// In tr, this message translates to:
  /// **'Yavaşça ağzından bırak'**
  String get breathExhale;

  /// No description provided for @breathStop.
  ///
  /// In tr, this message translates to:
  /// **'DURDUR'**
  String get breathStop;

  /// No description provided for @breathStart.
  ///
  /// In tr, this message translates to:
  /// **'BAŞLAT'**
  String get breathStart;

  /// No description provided for @breathQuote1.
  ///
  /// In tr, this message translates to:
  /// **'Her nefes seni rahatlatıyor 🌿'**
  String get breathQuote1;

  /// No description provided for @breathQuote2.
  ///
  /// In tr, this message translates to:
  /// **'Stresi bırak, huzuru al 🕊️'**
  String get breathQuote2;

  /// No description provided for @breathQuote3.
  ///
  /// In tr, this message translates to:
  /// **'Şu an güvendesin, rahatla 💙'**
  String get breathQuote3;

  /// No description provided for @breathQuote4.
  ///
  /// In tr, this message translates to:
  /// **'Her döngü seni iyileştiriyor ✨'**
  String get breathQuote4;

  /// No description provided for @breathQuote5.
  ///
  /// In tr, this message translates to:
  /// **'Zihni boşalt, bedeni gevşet 🧘'**
  String get breathQuote5;

  /// No description provided for @breathQuote6.
  ///
  /// In tr, this message translates to:
  /// **'Bu an sadece senin için 🌸'**
  String get breathQuote6;

  /// No description provided for @breathQuote7.
  ///
  /// In tr, this message translates to:
  /// **'Huzur her nefeste büyüyor 🌙'**
  String get breathQuote7;

  /// No description provided for @skinRedMetal.
  ///
  /// In tr, this message translates to:
  /// **'Kırmızı Metal'**
  String get skinRedMetal;

  /// No description provided for @skinBlueMetal.
  ///
  /// In tr, this message translates to:
  /// **'Mavi Metal'**
  String get skinBlueMetal;

  /// No description provided for @skinGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın'**
  String get skinGold;

  /// No description provided for @skinNeon.
  ///
  /// In tr, this message translates to:
  /// **'Neon'**
  String get skinNeon;

  /// No description provided for @skinHolo.
  ///
  /// In tr, this message translates to:
  /// **'Holografik'**
  String get skinHolo;

  /// No description provided for @skinSteel.
  ///
  /// In tr, this message translates to:
  /// **'Çelik'**
  String get skinSteel;

  /// No description provided for @skinRose.
  ///
  /// In tr, this message translates to:
  /// **'Rose'**
  String get skinRose;

  /// No description provided for @skinGalaxy.
  ///
  /// In tr, this message translates to:
  /// **'Galaksi'**
  String get skinGalaxy;

  /// No description provided for @spinnerKlasik.
  ///
  /// In tr, this message translates to:
  /// **'Klasik'**
  String get spinnerKlasik;

  /// No description provided for @spinnerCelikMavi.
  ///
  /// In tr, this message translates to:
  /// **'Çelik Mavi'**
  String get spinnerCelikMavi;

  /// No description provided for @spinnerAltinUclu.
  ///
  /// In tr, this message translates to:
  /// **'Altın Üçlü'**
  String get spinnerAltinUclu;

  /// No description provided for @spinnerNeon5.
  ///
  /// In tr, this message translates to:
  /// **'Neon 5'**
  String get spinnerNeon5;

  /// No description provided for @spinnerHologram.
  ///
  /// In tr, this message translates to:
  /// **'Hologram'**
  String get spinnerHologram;

  /// No description provided for @spinnerKaranlik.
  ///
  /// In tr, this message translates to:
  /// **'Karanlık'**
  String get spinnerKaranlik;

  /// No description provided for @spinnerRoseGold.
  ///
  /// In tr, this message translates to:
  /// **'Rose Gold'**
  String get spinnerRoseGold;

  /// No description provided for @spinnerGalaksi.
  ///
  /// In tr, this message translates to:
  /// **'Galaksi'**
  String get spinnerGalaksi;

  /// No description provided for @unlockRpm.
  ///
  /// In tr, this message translates to:
  /// **'{rpm} RPM kır'**
  String unlockRpm(int rpm);

  /// No description provided for @collectionTitle.
  ///
  /// In tr, this message translates to:
  /// **'KOLEKSİYON'**
  String get collectionTitle;

  /// No description provided for @collectionUnlock.
  ///
  /// In tr, this message translates to:
  /// **'Kilit açmak için: {hint}'**
  String collectionUnlock(String hint);

  /// No description provided for @collectionInfo.
  ///
  /// In tr, this message translates to:
  /// **'{arms} kol · {skin}'**
  String collectionInfo(int arms, String skin);

  /// No description provided for @smashTitle.
  ///
  /// In tr, this message translates to:
  /// **'PARÇALA'**
  String get smashTitle;

  /// No description provided for @smashPieces.
  ///
  /// In tr, this message translates to:
  /// **'{count} parça'**
  String smashPieces(int count);

  /// No description provided for @smashReset.
  ///
  /// In tr, this message translates to:
  /// **'Çarkı Sıfırla'**
  String get smashReset;

  /// No description provided for @smashHint.
  ///
  /// In tr, this message translates to:
  /// **'Kollara dokun, kopar!'**
  String get smashHint;

  /// No description provided for @orbitTitle.
  ///
  /// In tr, this message translates to:
  /// **'UZAY ORBİT'**
  String get orbitTitle;

  /// No description provided for @orbitSpins.
  ///
  /// In tr, this message translates to:
  /// **'{count} dönüş'**
  String orbitSpins(String count);

  /// No description provided for @glassGlass.
  ///
  /// In tr, this message translates to:
  /// **'Bardak'**
  String get glassGlass;

  /// No description provided for @glassBottle.
  ///
  /// In tr, this message translates to:
  /// **'Şişe'**
  String get glassBottle;

  /// No description provided for @glassVase.
  ///
  /// In tr, this message translates to:
  /// **'Vazo'**
  String get glassVase;

  /// No description provided for @glassJug.
  ///
  /// In tr, this message translates to:
  /// **'Damacana'**
  String get glassJug;

  /// No description provided for @glassPlate.
  ///
  /// In tr, this message translates to:
  /// **'Tabak'**
  String get glassPlate;

  /// No description provided for @glassSmashed.
  ///
  /// In tr, this message translates to:
  /// **'PARAMPARÇA!'**
  String get glassSmashed;

  /// No description provided for @glassAction.
  ///
  /// In tr, this message translates to:
  /// **'Dokunarak parçaları fırlat!'**
  String get glassAction;

  /// No description provided for @glassReset.
  ///
  /// In tr, this message translates to:
  /// **'YENİDEN'**
  String get glassReset;

  /// No description provided for @glassHitToSmash.
  ///
  /// In tr, this message translates to:
  /// **'VURARAK KIR!'**
  String get glassHitToSmash;

  /// No description provided for @menuBalloon.
  ///
  /// In tr, this message translates to:
  /// **'Balon Patlatma'**
  String get menuBalloon;

  /// No description provided for @menuBalloonDesc.
  ///
  /// In tr, this message translates to:
  /// **'Patlat ve rahatla!'**
  String get menuBalloonDesc;

  /// No description provided for @balloonCombo.
  ///
  /// In tr, this message translates to:
  /// **'Kombo'**
  String get balloonCombo;

  /// No description provided for @balloonBest.
  ///
  /// In tr, this message translates to:
  /// **'En İyi'**
  String get balloonBest;

  /// No description provided for @balloonTapToStart.
  ///
  /// In tr, this message translates to:
  /// **'Başlamak için dokun!'**
  String get balloonTapToStart;

  /// No description provided for @balloonNormal.
  ///
  /// In tr, this message translates to:
  /// **'Normal'**
  String get balloonNormal;

  /// No description provided for @balloonGold.
  ///
  /// In tr, this message translates to:
  /// **'Altın'**
  String get balloonGold;

  /// No description provided for @balloonIce.
  ///
  /// In tr, this message translates to:
  /// **'Buz'**
  String get balloonIce;

  /// No description provided for @balloonGameOver.
  ///
  /// In tr, this message translates to:
  /// **'OYUN BİTTİ'**
  String get balloonGameOver;

  /// No description provided for @balloonScore.
  ///
  /// In tr, this message translates to:
  /// **'Skor'**
  String get balloonScore;

  /// No description provided for @balloonRestart.
  ///
  /// In tr, this message translates to:
  /// **'TEKRAR OYNA'**
  String get balloonRestart;

  /// No description provided for @balloonNewRecord.
  ///
  /// In tr, this message translates to:
  /// **'🏆 YENİ REKOR!'**
  String get balloonNewRecord;

  /// No description provided for @menuStressBall.
  ///
  /// In tr, this message translates to:
  /// **'Stres Topu'**
  String get menuStressBall;

  /// No description provided for @menuStressBallDesc.
  ///
  /// In tr, this message translates to:
  /// **'Sık ve rahatla!'**
  String get menuStressBallDesc;

  /// No description provided for @stressBallHint.
  ///
  /// In tr, this message translates to:
  /// **'Sık, Bırak, Rahatla'**
  String get stressBallHint;

  /// No description provided for @statsTitle.
  ///
  /// In tr, this message translates to:
  /// **'İSTATİSTİKLER'**
  String get statsTitle;

  /// No description provided for @statsGeneral.
  ///
  /// In tr, this message translates to:
  /// **'GENEL'**
  String get statsGeneral;

  /// No description provided for @statsPlayTime.
  ///
  /// In tr, this message translates to:
  /// **'Oynama Süresi'**
  String get statsPlayTime;

  /// No description provided for @statsSessions.
  ///
  /// In tr, this message translates to:
  /// **'Oturumlar'**
  String get statsSessions;

  /// No description provided for @statsBadges.
  ///
  /// In tr, this message translates to:
  /// **'Rozetler'**
  String get statsBadges;

  /// No description provided for @statsBalloons.
  ///
  /// In tr, this message translates to:
  /// **'Balonlar'**
  String get statsBalloons;

  /// No description provided for @statsGlass.
  ///
  /// In tr, this message translates to:
  /// **'Cam Kırma'**
  String get statsGlass;

  /// No description provided for @statsModePlays.
  ///
  /// In tr, this message translates to:
  /// **'MOD KULLANIMLARI'**
  String get statsModePlays;

  /// No description provided for @dailyQuests.
  ///
  /// In tr, this message translates to:
  /// **'GÜNLÜK GÖREVLER'**
  String get dailyQuests;

  /// No description provided for @menuStats.
  ///
  /// In tr, this message translates to:
  /// **'İstatistikler'**
  String get menuStats;

  /// No description provided for @levelLabel.
  ///
  /// In tr, this message translates to:
  /// **'Seviye {level}'**
  String levelLabel(int level);

  /// No description provided for @questsCompact.
  ///
  /// In tr, this message translates to:
  /// **'{done}/{total} görev'**
  String questsCompact(int done, int total);

  /// No description provided for @tapToDismiss.
  ///
  /// In tr, this message translates to:
  /// **'Kapat'**
  String get tapToDismiss;

  /// No description provided for @questBalloonPop.
  ///
  /// In tr, this message translates to:
  /// **'{count} balon patlat'**
  String questBalloonPop(int count);

  /// No description provided for @questGlassSmash.
  ///
  /// In tr, this message translates to:
  /// **'{count} cam kir'**
  String questGlassSmash(int count);

  /// No description provided for @questPlayModes.
  ///
  /// In tr, this message translates to:
  /// **'{count} farkli mod oyna'**
  String questPlayModes(int count);

  /// No description provided for @questPlayTime.
  ///
  /// In tr, this message translates to:
  /// **'{count} dakika oyna'**
  String questPlayTime(int count);

  /// No description provided for @questBreath.
  ///
  /// In tr, this message translates to:
  /// **'{count} nefes dongusu'**
  String questBreath(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
