import 'dart:math' as math;
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

/// Gorev tipi
enum QuestType { rpm, balloon, glass, modes, playTime, breath }

/// Gunluk gorev tanimi
class DailyQuest {
  final String id;
  final QuestType type;
  final String emoji;
  final String Function(AppLocalizations l) getName;
  final double target;
  double progress;
  bool completed;

  DailyQuest({required this.id, required this.type, required this.emoji,
    required this.getName, required this.target, this.progress = 0, this.completed = false});
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

  // ── Gunluk gorevler ──
  List<DailyQuest> _dailyQuests = [];
  String _questDate = '';
  int _todayModesPlayed = 0;
  int _todayBreathCycles = 0;
  final Set<String> _todayModeSet = {};
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

  /// Tum gorev havuzu — her gun 5 tanesi rastgele secilir
  static List<DailyQuest> _questPool() => [
    // RPM gorevleri
    DailyQuest(id: 'rpm_10k', type: QuestType.rpm, emoji: '🔥',
      getName: (l) => '10.000 RPM', target: 10000),
    DailyQuest(id: 'rpm_25k', type: QuestType.rpm, emoji: '⚡',
      getName: (l) => '25.000 RPM', target: 25000),
    DailyQuest(id: 'rpm_50k', type: QuestType.rpm, emoji: '💥',
      getName: (l) => '50.000 RPM', target: 50000),
    // Balon gorevleri
    DailyQuest(id: 'balloon_30', type: QuestType.balloon, emoji: '🎈',
      getName: (l) => l.questBalloonPop(30), target: 30),
    DailyQuest(id: 'balloon_75', type: QuestType.balloon, emoji: '🎈',
      getName: (l) => l.questBalloonPop(75), target: 75),
    DailyQuest(id: 'balloon_150', type: QuestType.balloon, emoji: '🎈',
      getName: (l) => l.questBalloonPop(150), target: 150),
    // Cam kirma gorevleri
    DailyQuest(id: 'glass_10', type: QuestType.glass, emoji: '🔮',
      getName: (l) => l.questGlassSmash(10), target: 10),
    DailyQuest(id: 'glass_25', type: QuestType.glass, emoji: '🔮',
      getName: (l) => l.questGlassSmash(25), target: 25),
    // Mod cesitliligi
    DailyQuest(id: 'modes_3', type: QuestType.modes, emoji: '🎮',
      getName: (l) => l.questPlayModes(3), target: 3),
    DailyQuest(id: 'modes_5', type: QuestType.modes, emoji: '🎮',
      getName: (l) => l.questPlayModes(5), target: 5),
    // Oynama suresi
    DailyQuest(id: 'time_10', type: QuestType.playTime, emoji: '⏱️',
      getName: (l) => l.questPlayTime(10), target: 600),
    DailyQuest(id: 'time_20', type: QuestType.playTime, emoji: '⏱️',
      getName: (l) => l.questPlayTime(20), target: 1200),
    DailyQuest(id: 'time_30', type: QuestType.playTime, emoji: '⏱️',
      getName: (l) => l.questPlayTime(30), target: 1800),
    // Nefes egzersizi
    DailyQuest(id: 'breath_5', type: QuestType.breath, emoji: '🧘',
      getName: (l) => l.questBreath(5), target: 5),
    DailyQuest(id: 'breath_10', type: QuestType.breath, emoji: '🧘',
      getName: (l) => l.questBreath(10), target: 10),
  ];

  void _loadDailyQuests() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    _questDate = _prefs.getString('quest_date') ?? '';

    // Gunluk ek sayaclari yukle
    _todayModesPlayed = _prefs.getInt('quest_modes_count') ?? 0;
    _todayBreathCycles = _prefs.getInt('quest_breath_count') ?? 0;
    final modeSetList = _prefs.getStringList('quest_mode_set') ?? [];
    _todayModeSet.addAll(modeSetList);

    if (_questDate != today) {
      // Yeni gun — 5 gorev sec (her tipten max 1-2)
      _questDate = today;
      _prefs.setString('quest_date', today);
      _todayModesPlayed = 0;
      _todayBreathCycles = 0;
      _todayModeSet.clear();
      _prefs.setInt('quest_modes_count', 0);
      _prefs.setInt('quest_breath_count', 0);
      _prefs.setStringList('quest_mode_set', []);

      final pool = _questPool();
      // Gune gore deterministik karistirma (ayni gun ayni gorevler)
      final seed = today.hashCode;
      final rng = math.Random(seed);
      pool.shuffle(rng);

      // Her tipten max 1 sec, toplam 5
      final selected = <DailyQuest>[];
      final usedTypes = <QuestType>{};
      // Ilk tur: her tipten 1
      for (final q in pool) {
        if (selected.length >= 5) break;
        if (!usedTypes.contains(q.type)) {
          selected.add(q);
          usedTypes.add(q.type);
        }
      }
      // Ikinci tur: 5'i doldurmak icin kalanlardan ekle
      for (final q in pool) {
        if (selected.length >= 5) break;
        if (!selected.any((s) => s.id == q.id)) {
          selected.add(q);
        }
      }

      _dailyQuests = selected;
      // ID'leri kaydet
      _prefs.setStringList('quest_ids', selected.map((q) => q.id).toList());
      for (final q in selected) {
        _prefs.setDouble('quest_${q.id}', 0);
      }
    } else {
      // Bugunku gorevleri geri yukle
      final savedIds = _prefs.getStringList('quest_ids') ?? [];
      final pool = _questPool();
      _dailyQuests = [];
      for (final id in savedIds) {
        final template = pool.where((q) => q.id == id).firstOrNull;
        if (template != null) {
          final progress = _prefs.getDouble('quest_$id') ?? 0;
          _dailyQuests.add(DailyQuest(
            id: template.id, type: template.type, emoji: template.emoji,
            getName: template.getName, target: template.target,
            progress: progress, completed: progress >= template.target,
          ));
        }
      }
      // Eski versiyon uyumsuzlugu — gorevler bos kaldiysa yeniden olustur
      if (_dailyQuests.isEmpty) {
        _questDate = '';
        _prefs.remove('quest_date');
        _loadDailyQuests();
      }
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

    // Gunluk gorev ilerlemesi (sadece RPM tipi)
    _updateQuests(QuestType.rpm, amount);

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

  /// Gorev ilerlemesini guncelle (tip bazli)
  void _updateQuests(QuestType type, double amount) {
    for (final q in _dailyQuests) {
      if (!q.completed && q.type == type) {
        q.progress += amount;
        if (q.progress >= q.target) q.completed = true;
        _prefs.setDouble('quest_${q.id}', q.progress);
      }
    }
  }

  /// Istatistik kaydet
  void trackMode(String modeName) {
    _modePlayCounts[modeName] = (_modePlayCounts[modeName] ?? 0) + 1;
    _prefs.setInt('mode_$modeName', _modePlayCounts[modeName]!);
    final keys = _modePlayCounts.keys.toList();
    _prefs.setStringList('mode_play_keys', keys);

    // Gunluk mod cesitliligi gorevi
    if (!_todayModeSet.contains(modeName)) {
      _todayModeSet.add(modeName);
      _prefs.setStringList('quest_mode_set', _todayModeSet.toList());
      // Modes gorevlerini guncelle (progress = farkli mod sayisi)
      for (final q in _dailyQuests) {
        if (!q.completed && q.type == QuestType.modes) {
          q.progress = _todayModeSet.length.toDouble();
          if (q.progress >= q.target) q.completed = true;
          _prefs.setDouble('quest_${q.id}', q.progress);
        }
      }
    }
  }

  void addPlayTime(double seconds) {
    _totalPlayTimeSeconds += seconds;
    _prefs.setDouble('total_play_time', _totalPlayTimeSeconds);
    _updateQuests(QuestType.playTime, seconds);
  }

  void addBalloonPop([int count = 1]) {
    _totalBalloonsPop += count;
    _prefs.setInt('total_balloons_pop', _totalBalloonsPop);
    _updateQuests(QuestType.balloon, count.toDouble());
  }

  void addGlassSmash([int count = 1]) {
    _totalGlassSmash += count;
    _prefs.setInt('total_glass_smash', _totalGlassSmash);
    _updateQuests(QuestType.glass, count.toDouble());
  }

  void addBreathCycle([int count = 1]) {
    _todayBreathCycles += count;
    _prefs.setInt('quest_breath_count', _todayBreathCycles);
    _updateQuests(QuestType.breath, count.toDouble());
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

/// Rozet kutlama overlay widget'i — herhangi bir ekranda kullanilabilir.
class BadgeCelebration {
  static OverlayEntry? _current;

  static void show(BuildContext context, Badge badge) {
    _current?.remove();
    _current = null;
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

  static void dismiss() {
    _current?.remove();
    _current = null;
  }
}

/// Confetti parcacik verisi
class _Particle {
  double x, y, vx, vy, size, rotation, rotSpeed;
  Color color;
  _Particle({required this.x, required this.y, required this.vx, required this.vy,
    required this.size, required this.rotation, required this.rotSpeed, required this.color});
}

class _BadgeOverlay extends StatefulWidget {
  final Badge badge;
  final VoidCallback onDone;
  const _BadgeOverlay({required this.badge, required this.onDone});

  @override
  State<_BadgeOverlay> createState() => _BadgeOverlayState();
}

class _BadgeOverlayState extends State<_BadgeOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _glowCtrl;
  late AnimationController _confettiCtrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  late Animation<double> _emojiScale;
  final List<_Particle> _particles = [];
  final math.Random _rng = math.Random();
  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    // Ana animasyon
    _mainCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOutBack)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInBack)), weight: 20),
    ]).animate(_mainCtrl);
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 12),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 23),
    ]).animate(_mainCtrl);
    _emojiScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3).chain(CurveTween(curve: Curves.elasticOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
    ]).animate(_mainCtrl);

    // Glow nabiz efekti
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);

    // Confetti animasyonu
    _confettiCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3500));
    _generateParticles();

    _mainCtrl.forward().then((_) {
      if (mounted && !_dismissing) widget.onDone();
    });
    _confettiCtrl.forward();

    HapticFeedback.heavyImpact();
  }

  void _generateParticles() {
    final colors = [
      widget.badge.color,
      widget.badge.color.withValues(alpha: 0.7),
      Colors.white,
      const Color(0xFFFFD700),
      const Color(0xFFFF006E),
      const Color(0xFF00E5FF),
    ];
    for (int i = 0; i < 40; i++) {
      final angle = _rng.nextDouble() * 2 * math.pi;
      final speed = 150 + _rng.nextDouble() * 300;
      _particles.add(_Particle(
        x: 0, y: 0,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed - 100,
        size: 3 + _rng.nextDouble() * 6,
        rotation: _rng.nextDouble() * math.pi * 2,
        rotSpeed: (_rng.nextDouble() - 0.5) * 10,
        color: colors[_rng.nextInt(colors.length)],
      ));
    }
  }

  void _dismiss() {
    if (_dismissing) return;
    _dismissing = true;
    _mainCtrl.animateTo(1.0, duration: const Duration(milliseconds: 300),
      curve: Curves.easeIn).then((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _glowCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_mainCtrl, _glowCtrl, _confettiCtrl]),
        builder: (context, _) {
          final opacity = _opacity.value.clamp(0.0, 1.0);
          final scale = _scale.value.clamp(0.0, 2.0);
          final emojiS = _emojiScale.value.clamp(0.0, 2.0);
          final glowPulse = 0.3 + _glowCtrl.value * 0.3;
          final sz = MediaQuery.of(context).size;

          return Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              behavior: HitTestBehavior.opaque,
              child: SizedBox.expand(
                child: Stack(
                  children: [
                    // Arka plan karartma
                    Container(color: Colors.black.withValues(alpha: opacity * 0.5)),

                    // Confetti parcaciklari
                    if (_confettiCtrl.isAnimating || _confettiCtrl.value > 0)
                      CustomPaint(
                        size: sz,
                        painter: _ConfettiPainter(
                          particles: _particles,
                          progress: _confettiCtrl.value,
                          center: Offset(sz.width / 2, sz.height / 2),
                        ),
                      ),

                    // Ana kart
                    Center(
                      child: Opacity(
                        opacity: opacity,
                        child: Transform.scale(
                          scale: scale,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A0820),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: widget.badge.color.withValues(alpha: 0.5 + glowPulse * 0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: widget.badge.color.withValues(alpha: glowPulse * 0.5),
                                  blurRadius: 50 + glowPulse * 30,
                                  spreadRadius: 5,
                                ),
                                BoxShadow(
                                  color: widget.badge.color.withValues(alpha: glowPulse * 0.15),
                                  blurRadius: 100,
                                  spreadRadius: 15,
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Emoji — bounce efekti
                                Transform.scale(
                                  scale: emojiS,
                                  child: Text(widget.badge.emoji, style: const TextStyle(fontSize: 72)),
                                ),
                                const SizedBox(height: 16),
                                // Yildiz efekti
                                Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text('✦ ', style: TextStyle(
                                    color: widget.badge.color.withValues(alpha: 0.4 + glowPulse * 0.4),
                                    fontSize: 14)),
                                  Text(AppLocalizations.of(context)?.newBadge ?? 'YENi ROZET!', style: TextStyle(
                                    color: widget.badge.color, fontSize: 14,
                                    fontWeight: FontWeight.w800, letterSpacing: 4,
                                  )),
                                  Text(' ✦', style: TextStyle(
                                    color: widget.badge.color.withValues(alpha: 0.4 + glowPulse * 0.4),
                                    fontSize: 14)),
                                ]),
                                const SizedBox(height: 10),
                                // Rozet ismi
                                Text(localizedBadgeName(context, widget.badge.id), style: const TextStyle(
                                  color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900,
                                )),
                                const SizedBox(height: 8),
                                // RPM
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: widget.badge.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('${widget.badge.threshold.toStringAsFixed(0)} RPM', style: TextStyle(
                                    color: widget.badge.color.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w700,
                                  )),
                                ),
                                const SizedBox(height: 16),
                                // Kapat ipucu
                                Text(AppLocalizations.of(context)?.tapToDismiss ?? 'Kapat',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Confetti parcacik painter
class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Offset center;

  _ConfettiPainter({required this.particles, required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    final gravity = 400.0;
    for (final p in particles) {
      final x = center.dx + p.vx * t;
      final y = center.dy + p.vy * t + 0.5 * gravity * t * t;
      final opacity = (1.0 - t).clamp(0.0, 1.0);
      if (opacity <= 0 || y > size.height + 20 || x < -20 || x > size.width + 20) continue;

      final paint = Paint()..color = p.color.withValues(alpha: opacity * 0.8);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * t);
      final rect = Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1)), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
