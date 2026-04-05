import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';
import 'splash_screen.dart';
import 'game_state.dart';
import 'audio_engine.dart';
import 'ad_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GameState.instance.init();
  await AudioEngine.instance.init();
  await AdManager.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('app_language') ?? 'tr';
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF03020A),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(StressCarkiApp(initialLocale: Locale(savedLang)));
}

class StressCarkiApp extends StatefulWidget {
  final Locale initialLocale;
  const StressCarkiApp({super.key, required this.initialLocale});

  static void setLocale(BuildContext context, Locale locale) {
    final state = context.findAncestorStateOfType<_StressCarkiAppState>();
    state?._setLocale(locale);
  }

  @override
  State<StressCarkiApp> createState() => _StressCarkiAppState();
}

class _StressCarkiAppState extends State<StressCarkiApp> with WidgetsBindingObserver {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana alınınca müziği durdur
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AudioEngine.instance.pause();
    } else if (state == AppLifecycleState.resumed) {
      AudioEngine.instance.resume();
    }
  }

  void _setLocale(Locale locale) async {
    setState(() => _locale = locale);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('app_language', locale.languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (ctx) => AppLocalizations.of(ctx)?.appTitle ?? 'Stres Çarkı',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [],
      locale: _locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('tr'),
        Locale('en'),
        Locale('de'),
        Locale('fr'),
        Locale('es'),
      ],
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF03020A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6C63FF),
          secondary: Color(0xFF7C4DFF),
          surface: Color(0xFF0A0820),
        ),
        useMaterial3: true,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
