import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'main.dart';
import 'game_state.dart';
import 'sound_engine.dart';
import 'spinner_collection.dart';
import 'spinner_screen.dart';
import 'smash_screen.dart';
import 'glass_smash_screen.dart';
import 'orbit_screen.dart';
import 'breath_screen.dart';
import 'balloon_pop_screen.dart';
import 'stress_ball_screen.dart';
import 'stats_screen.dart';

// ════════════════════════════════════════════════════════════════════
//  ANA MENÜ — Premium Tasarım
// ════════════════════════════════════════════════════════════════════

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _entryCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  void _navigate(Widget screen) {
    SoundEngine.uiTap();
    Navigator.push(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => screen,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _showLanguageDialog() {
    final languages = [
      ('TR', 'Türkçe', 'tr', const Color(0xFFE30A17)),
      ('EN', 'English', 'en', const Color(0xFF1A237E)),
      ('DE', 'Deutsch', 'de', const Color(0xFFDD0000)),
      ('FR', 'Français', 'fr', const Color(0xFF0055A4)),
      ('ES', 'Español', 'es', const Color(0xFFC60B1E)),
    ];

    // Şu anki dil
    final currentLocale = Localizations.localeOf(context).languageCode;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0820),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.white12, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Icon(Icons.language, color: Colors.white54, size: 32),
            const SizedBox(height: 16),
            ...languages.map((lang) {
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
                      // Dil kodu badge
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
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showBadges() {
    final gs = GameState.instance;
    final l = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0A0820),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (_, scrollCtrl) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(
                  color: Colors.white12, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text(l.badgesTitle, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 6),
                Text(l.badgesTotal(gs.formattedRpm),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
                // İlerleme barı
                if (gs.nextBadge != null) ...[
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: gs.progressToNext,
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      valueColor: AlwaysStoppedAnimation(gs.nextBadge!.color.withValues(alpha: 0.6)),
                      minHeight: 4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${localizedBadgeName(context, gs.nextBadge!.id)} → ${gs.nextBadge!.threshold.toStringAsFixed(0)} RPM',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                  ),
                ],
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: earned
                              ? b.color.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: earned ? b.color.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.04)),
                        ),
                        child: Row(children: [
                          Text(earned ? b.emoji : '🔒',
                            style: TextStyle(fontSize: 28, color: earned ? null : Colors.white24)),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localizedBadgeName(context, b.id),
                                style: TextStyle(
                                  color: earned ? Colors.white : Colors.white30,
                                  fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${b.threshold.toStringAsFixed(0)} RPM',
                                style: TextStyle(
                                  color: earned ? b.color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.15),
                                  fontSize: 12),
                              ),
                            ],
                          )),
                          if (earned) Icon(Icons.check_circle, color: b.color, size: 22),
                        ]),
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

  void _showAbout() {
    final l = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A0820),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color(0xFFDC3232), Color(0xFF8C1423)]),
            ),
            child: const Icon(Icons.cyclone, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Text(l.aboutTitle, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        ]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('v1.0', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13)),
              const SizedBox(height: 12),
              Text(l.aboutDescription, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.3), size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(l.aboutLegalTitle, style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45), fontSize: 11, fontWeight: FontWeight.w700))),
                    ]),
                    const SizedBox(height: 8),
                    Text(l.aboutLegalText, style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3), fontSize: 10, height: 1.5)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(l.aboutCopyright, style: TextStyle(
                color: Colors.white.withValues(alpha: 0.25), fontSize: 10))),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.aboutOk, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final gs = GameState.instance;
    final sz = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF03020A),
      body: AnimatedBuilder(
        animation: Listenable.merge([_pulseCtrl, _entryCtrl]),
        builder: (_, __) {
          final entry = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOutCubic).value;

          return Stack(
            children: [
              // ── Arka plan ──
              Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.5),
                    radius: 1.2,
                    colors: [Color(0xFF120810), Color(0xFF060410), Color(0xFF03020A)],
                  ),
                ),
              ),

              // ── Ambient glow ──
              Positioned(
                left: sz.width / 2 - 100,
                top: 60,
                child: Container(
                  width: 200, height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFCC3333).withValues(alpha: 0.06 + _pulseCtrl.value * 0.03),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    // ── Header ──
                    Opacity(
                      opacity: entry,
                      child: Transform.translate(
                        offset: Offset(0, (1 - entry) * -20),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Row(
                            children: [
                              // Logo
                              Container(
                                width: 48, height: 48,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: const RadialGradient(
                                    colors: [Color(0xFFDC3232), Color(0xFF8C1423)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFCC3333).withValues(alpha: 0.3 + _pulseCtrl.value * 0.1),
                                      blurRadius: 15,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.cyclone, color: Colors.white, size: 26),
                              ),
                              const SizedBox(width: 14),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l.appTitle.toUpperCase(), style: const TextStyle(
                                    color: Colors.white, fontSize: 18,
                                    fontWeight: FontWeight.w900, letterSpacing: 3,
                                  )),
                                  Text(l.headerSubtitle, style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    fontSize: 11, letterSpacing: 1,
                                  )),
                                ],
                              ),
                              const Spacer(),
                              // RPM badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFCC3333).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFFCC3333).withValues(alpha: 0.2)),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Text('⚡', style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(gs.formattedRpm, style: const TextStyle(
                                    color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w800)),
                                ]),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Mod kartları ──
                    Expanded(
                      child: Opacity(
                        opacity: entry,
                        child: Transform.translate(
                          offset: Offset(0, (1 - entry) * 30),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            children: [
                              // Ana mod — Spinner (büyük kart)
                              _buildMainCard(
                                icon: Icons.cyclone,
                                iconColor: const Color(0xFFCC3333),
                                title: l.menuSpinner,
                                subtitle: l.menuSpinnerDesc,
                                onTap: () => _navigate(const SpinnerScreen()),
                              ),

                              const SizedBox(height: 12),

                              // 2li grid
                              Row(children: [
                                Expanded(child: _buildCard(
                                  emoji: '🌌',
                                  title: l.menuOrbit,
                                  color: const Color(0xFF6C63FF),
                                  onTap: () => _navigate(OrbitScreen(spinnerModel: SpinnerCollection.all[0])),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _buildCard(
                                  emoji: '💥',
                                  title: l.menuSmash,
                                  color: const Color(0xFFFF5722),
                                  onTap: () => _navigate(SmashScreen(spinnerModel: SpinnerCollection.all[0])),
                                )),
                              ]),

                              const SizedBox(height: 10),

                              Row(children: [
                                Expanded(child: _buildCard(
                                  emoji: '🔮',
                                  title: l.menuGlass,
                                  color: const Color(0xFF00BCD4),
                                  onTap: () => _navigate(const GlassSmashScreen()),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _buildCard(
                                  emoji: '🎈',
                                  title: l.menuBalloon,
                                  color: const Color(0xFFFF006E),
                                  onTap: () => _navigate(const BalloonPopScreen()),
                                )),
                              ]),

                              const SizedBox(height: 10),

                              Row(children: [
                                Expanded(child: _buildCard(
                                  emoji: '🧘',
                                  title: l.menuBreath,
                                  color: const Color(0xFF4CAF50),
                                  onTap: () => _navigate(const BreathScreen()),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _buildCard(
                                  emoji: '🤜',
                                  title: l.menuStressBall,
                                  color: const Color(0xFF2962FF),
                                  onTap: () => _navigate(const StressBallScreen()),
                                )),
                              ]),

                              const SizedBox(height: 10),

                              Row(children: [
                                Expanded(child: _buildCard(
                                  emoji: '🏆',
                                  title: l.badgesTitle,
                                  color: const Color(0xFFFFD700),
                                  onTap: _showBadges,
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: _buildCard(
                                  emoji: '📊',
                                  title: l.menuStats,
                                  color: const Color(0xFF6C63FF),
                                  onTap: () => _navigate(const StatsScreen()),
                                )),
                              ]),

                              const SizedBox(height: 20),

                              // Alt aksiyonlar
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildSmallBtn(Icons.language, l.menuLanguage, _showLanguageDialog),
                                  const SizedBox(width: 12),
                                  _buildSmallBtn(Icons.info_outline, l.aboutTitle, _showAbout),
                                ],
                              ),

                              const SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Grid kart (animasyonlu) ──
  Widget _buildCard({
    required String emoji,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return _AnimatedCard(
      emoji: emoji,
      title: title,
      color: color,
      onTap: onTap,
    );
  }

  // ── Ana kart (animasyonlu) ──
  Widget _buildMainCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return _AnimatedMainCard(
      icon: icon,
      iconColor: iconColor,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  // ── Küçük buton ──
  Widget _buildSmallBtn(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: Colors.white38, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
            color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Animasyonlu Kart Widget'ları — dokunma scale + glow efekti
// ════════════════════════════════════════════════════════════════════

class _AnimatedCard extends StatefulWidget {
  final String emoji;
  final String title;
  final Color color;
  final VoidCallback onTap;
  const _AnimatedCard({required this.emoji, required this.title, required this.color, required this.onTap});
  @override
  State<_AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<_AnimatedCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); setState(() => _pressing = true); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _ctrl.reverse(); setState(() => _pressing = false); widget.onTap(); },
      onTapCancel: () { _ctrl.reverse(); setState(() => _pressing = false); },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: _pressing ? 0.12 : 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: widget.color.withValues(alpha: _pressing ? 0.25 : 0.10)),
              boxShadow: _pressing ? [
                BoxShadow(color: widget.color.withValues(alpha: 0.15), blurRadius: 15),
              ] : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.emoji, style: const TextStyle(fontSize: 26)),
                Text(widget.title, style: const TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedMainCard extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AnimatedMainCard({required this.icon, required this.iconColor, required this.title, required this.subtitle, required this.onTap});
  @override
  State<_AnimatedMainCard> createState() => _AnimatedMainCardState();
}

class _AnimatedMainCardState extends State<_AnimatedMainCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _pressing = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = widget.iconColor;
    return GestureDetector(
      onTapDown: (_) { _ctrl.forward(); setState(() => _pressing = true); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _ctrl.reverse(); setState(() => _pressing = false); widget.onTap(); },
      onTapCancel: () { _ctrl.reverse(); setState(() => _pressing = false); },
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [
                  c.withValues(alpha: _pressing ? 0.18 : 0.12),
                  c.withValues(alpha: _pressing ? 0.08 : 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.withValues(alpha: _pressing ? 0.3 : 0.15)),
              boxShadow: [
                BoxShadow(color: c.withValues(alpha: _pressing ? 0.2 : 0.08), blurRadius: _pressing ? 30 : 20),
              ],
            ),
            child: Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [c, c.withValues(alpha: 0.5)]),
                  boxShadow: [BoxShadow(color: c.withValues(alpha: 0.3), blurRadius: 12)],
                ),
                child: Icon(widget.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: const TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(widget.subtitle, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
                ],
              )),
              Icon(Icons.arrow_forward_ios, color: Colors.white.withValues(alpha: 0.2), size: 18),
            ]),
          ),
        ),
      ),
    );
  }
}
