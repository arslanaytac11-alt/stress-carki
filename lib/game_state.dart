import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'l10n/app_localizations.dart';

/// Rozet tanımı
class Badge {
  final String id;
  final String name;
  final String emoji;
  final double threshold;
  final Color color;

  const Badge({
    required this.id,
    required this.name,
    required this.emoji,
    required this.threshold,
    required this.color,
  });
}

/// Günlük görev tanımı
class DailyQuest {
  final String id;
  final String Function(AppLocalizations l) getName;
  final double target;
  double progress;
  bool completed;

  DailyQuest({required this.id, required this.getName, required this.target, this.progress = 0, this.completed = false});
}

/// Global oyun durumu — tüm ekranlar paylaşır.
class GameState {
  static final GameState _instance = GameState._();
  static GameState get instance => _instance;
  GameState._();

  late SharedPreferences _prefs;
  double _totalRpm = 0.0;
  double _saveCounter = 0.0;
  List<String> _earnedBadges = [];
  bool _initialized = false;

  // ── XP / Seviye sistemi ──
  double _xp = 0.0;
  int _level = 1;
  double get xp => _xp;
  int get level => _level;
  double get xpForNextLevel => _level * 500.0; // Her seviye 500 XP daha
  double get xpProgress => (_xp / xpForNextLevel).clamp(0.0, 1.0);

  // ── İstatistikler ──
  int _totalSessions = 0;
  double _totalPlayTimeSeconds = 0.0;
  int _totalBalloonsPop = 0;
  int _totalGlassSmash = 0;
  Map<String, int> _modePlayCounts = {};

  int get totalSessions => _totalSessions;
  double get totalPlayTimeSeconds => _totalPlayTimeSeconds;
  int get totalBalloonsPop => _totalBalloonsPop;
  int get totalGlassSmash => _totalGlassSmash;
  Map<String, int> get modePlayCounts => Map.unmodifiable(_modePlayCounts);

  // ── Günlük görevler ──
  List<DailyQuest> _dailyQuests = [];
  String _questDate = '';
  List<DailyQuest> get dailyQuests => _dailyQuests;
  int get completedQuestsToday => _dailyQuests.where((q) => q.completed).length;

  static const List<Badge> badges = [
    Badge(id: 'baslangic', name: 'Başlangıç', emoji: '🌱', threshold: 10000, color: Color(0xFF8BC34A)),
    Badge(id: 'caylak', name: 'Çaylak', emoji: '🥉', threshold: 50000, color: Color(0xFFCD7F32)),
    Badge(id: 'merakli', name: 'Meraklı', emoji: '🔍', threshold: 150000, color: Color(0xFF03A9F4)),
    Badge(id: 'sporcu', name: 'Sporcu', emoji: '💪', threshold: 300000, color: Color(0xFF2196F3)),
    Badge(id: 'azimli', name: 'Azimli', emoji: '🔥', threshold: 500000, color: Color(0xFFFF5722)),
    Badge(id: 'usta', name: 'Usta', emoji: '🥈', threshold: 750000, color: Color(0xFFC0C0C0)),
    Badge(id: 'uzman', name: 'Uzman', emoji: '🎯', threshold: 1000000, color: Color(0xFF009688)),
    Badge(id: 'efsane', name: 'Efsane', emoji: '🥇', threshold: 1500000, color: Color(0xFFFFD700)),
    Badge(id: 'sampiyon', name: 'Şampiyon', emoji: '🏆', threshold: 2000000, color: Color(0xFFE91E63)),
    Badge(id: 'elmas', name: 'Elmas', emoji: '💎', threshold: 3000000, color: Color(0xFF00BCD4)),
    Badge(id: 'tanri', name: 'Tanrı', emoji: '⚡', threshold: 5000000, color: Color(0xFFAA00FF)),
    Badge(id: 'galaktik', name: 'Galaktik', emoji: '🌌', threshold: 8000000, color: Color(0xFF00E5FF)),
    Badge(id: 'evrensel', name: 'Evrensel', emoji: '🪐', threshold: 12000000, color: Color(0xFFFF6F00)),
    Badge(id: 'sonsuz', name: 'Sonsuz', emoji: '♾️', threshold: 20000000, color: Color(0xFFD500F9)),
  ];

  double get totalRpm => _totalRpm;
  List<String> get earnedBadges => List.unmodifiable(_earnedBadges);

  Badge? get currentBadge {
    Badge? best;
    for (final b in badges) {
      if (_earnedBadges.contains(b.id)) best = b;
    }
    return best;
  }

  /// Sonraki hedef rozet
  Badge? get nextBadge {
    for (final b in badges) {
      if (!_earnedBadges.contains(b.id)) return b;
    }
    return null;
  }

  /// İlerleme yüzdesi (sonraki rozete doğru)
  double get progressToNext {
    final next = nextBadge;
    if (next == null) return 1.0;
    final prev = currentBadge;
    final from = prev?.threshold ?? 0;
    return ((_totalRpm - from) / (next.threshold - from)).clamp(0.0, 1.0);
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _totalRpm = _prefs.getDouble('total_rpm') ?? 0.0;
    _earnedBadges = _prefs.getStringList('earned_badges') ?? [];
    _xp = _prefs.getDouble('xp') ?? 0.0;
    _level = _prefs.getInt('level') ?? 1;
    _totalSessions = _prefs.getInt('total_sessions') ?? 0;
    _totalPlayTimeSeconds = _prefs.getDouble('total_play_time') ?? 0.0;
    _totalBalloonsPop = _prefs.getInt('total_balloons_pop') ?? 0;
    _totalGlassSmash = _prefs.getInt('total_glass_smash') ?? 0;

    // Mode play counts
    final modeKeys = _prefs.getStringList('mode_play_keys') ?? [];
    for (final key in modeKeys) {
      _modePlayCounts[key] = _prefs.getInt('mode_$key') ?? 0;
    }

    // Günlük görevleri yükle/yenile
    _loadDailyQuests();

    _totalSessions++;
    _prefs.setInt('total_sessions', _totalSessions);
    _initialized = true;
  }

  void _loadDailyQuests() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _questDate = _prefs.getString('quest_date') ?? '';

    if (_questDate != today) {
      // Yeni gün — yeni görevler
      _questDate = today;
      _prefs.setString('quest_date', today);
      _dailyQuests = [
        DailyQuest(id: 'rpm_500', getName: (l) => '500 RPM', target: 500),
        DailyQuest(id: 'rpm_2000', getName: (l) => '2000 RPM', target: 2000),
        DailyQuest(id: 'rpm_5000', getName: (l) => '5000 RPM', target: 5000),
      ];
      _prefs.setDouble('quest_rpm_500', 0);
      _prefs.setDouble('quest_rpm_2000', 0);
      _prefs.setDouble('quest_rpm_5000', 0);
    } else {
      // Bugünkü görevleri geri yükle
      _dailyQuests = [
        DailyQuest(id: 'rpm_500', getName: (l) => '500 RPM', target: 500,
          progress: _prefs.getDouble('quest_rpm_500') ?? 0,
          completed: (_prefs.getDouble('quest_rpm_500') ?? 0) >= 500),
        DailyQuest(id: 'rpm_2000', getName: (l) => '2000 RPM', target: 2000,
          progress: _prefs.getDouble('quest_rpm_2000') ?? 0,
          completed: (_prefs.getDouble('quest_rpm_2000') ?? 0) >= 2000),
        DailyQuest(id: 'rpm_5000', getName: (l) => '5000 RPM', target: 5000,
          progress: _prefs.getDouble('quest_rpm_5000') ?? 0,
          completed: (_prefs.getDouble('quest_rpm_5000') ?? 0) >= 5000),
      ];
    }
  }

  /// RPM ekle. Yeni rozet kazanıldıysa döndürür.
  List<Badge> addRpm(double amount) {
    if (amount <= 0 || !_initialized) return [];
    _totalRpm += amount;

    // XP ekle (RPM'in %10'u kadar XP)
    _xp += amount * 0.1;
    while (_xp >= xpForNextLevel) {
      _xp -= xpForNextLevel;
      _level++;
      _prefs.setInt('level', _level);
      HapticFeedback.mediumImpact();
    }

    // Günlük görev ilerlemesi
    for (final q in _dailyQuests) {
      if (!q.completed) {
        q.progress += amount;
        if (q.progress >= q.target) q.completed = true;
      }
    }

    // Her 100 RPM'de bir kaydet
    _saveCounter += amount;
    if (_saveCounter >= 100) {
      _saveCounter = 0;
      _prefs.setDouble('total_rpm', _totalRpm);
      _prefs.setDouble('xp', _xp);
      // Görev ilerlemesi kaydet
      for (final q in _dailyQuests) {
        _prefs.setDouble('quest_${q.id}', q.progress);
      }
    }

    // Rozet kontrolü — tümünü kontrol et
    final newBadges = <Badge>[];
    for (final b in badges) {
      if (!_earnedBadges.contains(b.id) && _totalRpm >= b.threshold) {
        _earnedBadges.add(b.id);
        newBadges.add(b);
      }
    }
    if (newBadges.isNotEmpty) {
      _prefs.setStringList('earned_badges', _earnedBadges);
      _prefs.setDouble('total_rpm', _totalRpm);
      HapticFeedback.heavyImpact();
    }
    return newBadges;
  }

  /// İstatistik kaydet
  void trackMode(String modeName) {
    _modePlayCounts[modeName] = (_modePlayCounts[modeName] ?? 0) + 1;
    _prefs.setInt('mode_$modeName', _modePlayCounts[modeName]!);
    final keys = _modePlayCounts.keys.toList();
    _prefs.setStringList('mode_play_keys', keys);
  }

  void addPlayTime(double seconds) {
    _totalPlayTimeSeconds += seconds;
    _prefs.setDouble('total_play_time', _totalPlayTimeSeconds);
  }

  void addBalloonPop([int count = 1]) {
    _totalBalloonsPop += count;
    _prefs.setInt('total_balloons_pop', _totalBalloonsPop);
  }

  void addGlassSmash([int count = 1]) {
    _totalGlassSmash += count;
    _prefs.setInt('total_glass_smash', _totalGlassSmash);
  }

  /// Zorla kaydet (ekran çıkışında)
  void save() {
    _prefs.setDouble('total_rpm', _totalRpm);
    _prefs.setDouble('xp', _xp);
    _prefs.setInt('level', _level);
    for (final q in _dailyQuests) {
      _prefs.setDouble('quest_${q.id}', q.progress);
    }
  }

  /// Kompakt RPM formatı: 1234 → "1.2K", 12345 → "12.3K"
  String get formattedRpm {
    if (_totalRpm < 1000) return _totalRpm.toStringAsFixed(0);
    if (_totalRpm < 10000) return '${(_totalRpm / 1000).toStringAsFixed(1)}K';
    if (_totalRpm < 1000000) return '${(_totalRpm / 1000).toStringAsFixed(0)}K';
    return '${(_totalRpm / 1000000).toStringAsFixed(1)}M';
  }

  static String _formatNum(double v) {
    if (v < 1000) return v.toStringAsFixed(0);
    if (v < 1000000) return '${(v / 1000).toStringAsFixed(1)}K';
    return '${(v / 1000000).toStringAsFixed(1)}M';
  }

}

/// Badge ismini locale'e göre çevir
String localizedBadgeName(BuildContext context, String badgeId) {
  final l = AppLocalizations.of(context);
  if (l == null) return badgeId;
  switch (badgeId) {
    case 'baslangic': return l.badgeBaslangic;
    case 'caylak': return l.badgeCaylak;
    case 'merakli': return l.badgeMerakli;
    case 'sporcu': return l.badgeSporcu;
    case 'azimli': return l.badgeAzimli;
    case 'usta': return l.badgeUsta;
    case 'uzman': return l.badgeUzman;
    case 'efsane': return l.badgeEfsane;
    case 'sampiyon': return l.badgeSampiyon;
    case 'elmas': return l.badgeElmas;
    case 'tanri': return l.badgeTanri;
    case 'galaktik': return l.badgeGalaktik;
    case 'evrensel': return l.badgeEvrensel;
    case 'sonsuz': return l.badgeSonsuz;
    default: return badgeId;
  }
}

/// Rozet kutlama overlay widget'ı — herhangi bir ekranda kullanılabilir.
class BadgeCelebration {
  static OverlayEntry? _current;

  static void show(BuildContext context, Badge badge) {
    _current?.remove();
    final overlay = Overlay.of(context);

    late OverlayEntry entry;
    entry = OverlayEntry(builder: (ctx) => _BadgeOverlay(
      badge: badge,
      onDone: () {
        if (entry.mounted) entry.remove();
        if (_current == entry) _current = null;
      },
    ));

    _current = entry;
    overlay.insert(entry);
  }
}

class _BadgeOverlay extends StatefulWidget {
  final Badge badge;
  final VoidCallback onDone;
  const _BadgeOverlay({required this.badge, required this.onDone});

  @override
  State<_BadgeOverlay> createState() => _BadgeOverlayState();
}

class _BadgeOverlayState extends State<_BadgeOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.05).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.8).chain(CurveTween(curve: Curves.easeIn)), weight: 20),
    ]).animate(_ctrl);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 25),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final opacity = _opacity.value.clamp(0.0, 1.0);
          final scale = _scale.value.clamp(0.0, 2.0);
          return Material(
            color: Colors.transparent,
            child: SizedBox.expand(
              child: IgnorePointer(
                child: Container(
                  color: Colors.black.withValues(alpha: opacity * 0.4),
                  child: Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A0820),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: widget.badge.color.withValues(alpha: 0.6), width: 2),
                            boxShadow: [
                              BoxShadow(color: widget.badge.color.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 5),
                              BoxShadow(color: widget.badge.color.withValues(alpha: 0.15), blurRadius: 80, spreadRadius: 10),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Emoji büyük
                              Text(widget.badge.emoji, style: const TextStyle(fontSize: 64)),
                              const SizedBox(height: 14),
                              // Yıldız efekti
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('✦ ', style: TextStyle(color: widget.badge.color.withValues(alpha: 0.6), fontSize: 12)),
                                Text(AppLocalizations.of(context)?.newBadge ?? 'YENİ ROZET!', style: TextStyle(
                                  color: widget.badge.color, fontSize: 14,
                                  fontWeight: FontWeight.w800, letterSpacing: 4,
                                )),
                                Text(' ✦', style: TextStyle(color: widget.badge.color.withValues(alpha: 0.6), fontSize: 12)),
                              ]),
                              const SizedBox(height: 8),
                              Text(localizedBadgeName(context, widget.badge.id), style: const TextStyle(
                                color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900,
                              )),
                              const SizedBox(height: 6),
                              Text('${widget.badge.threshold.toStringAsFixed(0)} RPM', style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4), fontSize: 13,
                              )),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
