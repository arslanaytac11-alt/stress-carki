import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _main;
  late AnimationController _pulse;
  late AnimationController _ring;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _main = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800),
    );
    _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _ring = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400),
    )..repeat();

    _logoScale = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.0, 0.35, curve: Curves.elasticOut)),
    );
    _logoFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.0, 0.2, curve: Curves.easeOut)),
    );
    _titleSlide = Tween(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.15, 0.5, curve: Curves.easeOutCubic)),
    );
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.15, 0.45, curve: Curves.easeOut)),
    );
    _subtitleFade = Tween(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _main, curve: const Interval(0.3, 0.6, curve: Curves.easeOut)),
    );

    _main.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            transitionsBuilder: (_, anim, __, child) => FadeTransition(
              opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _main.dispose();
    _pulse.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF03020A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_main, _pulse, _ring]),
        builder: (_, __) => Stack(
          children: [
            // Arka plan
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.2), radius: 1.0,
                  colors: [Color(0xFF0D0820), Color(0xFF03020A)],
                ),
              ),
            ),
            // Parlayan ring
            Center(
              child: Opacity(
                opacity: _logoFade.value * 0.3,
                child: Transform.scale(
                  scale: 0.5 + _ring.value,
                  child: Container(
                    width: 200, height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFBB44DD).withValues(alpha: (1 - _ring.value) * 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Logo + Text
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Opacity(
                    opacity: _logoFade.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Container(
                        width: 100, height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFBB44DD).withValues(alpha: 0.4 + _pulse.value * 0.2),
                              blurRadius: 30 + _pulse.value * 15,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/app_icon_1024x1024.png', width: 100, height: 100, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Opacity(
                    opacity: _titleFade.value,
                    child: Transform.translate(
                      offset: Offset(0, _titleSlide.value),
                      child: Text(AppLocalizations.of(context)!.appTitle.toUpperCase(), style: const TextStyle(
                        color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.w900, letterSpacing: 6,
                      )),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Opacity(
                    opacity: _subtitleFade.value,
                    child: Text(AppLocalizations.of(context)!.splashTagline,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Alt loading
            Positioned(
              left: 0, right: 0, bottom: 60,
              child: Opacity(
                opacity: _subtitleFade.value * 0.6,
                child: Center(
                  child: SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(
                        const Color(0xFFBB44DD).withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
