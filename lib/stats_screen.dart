import 'package:flutter/material.dart';
import 'game_state.dart';
import 'l10n/app_localizations.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final gs = GameState.instance;
    final l = AppLocalizations.of(context)!;

    // Oynanma süresini formatla
    final totalMin = (gs.totalPlayTimeSeconds / 60).floor();
    final totalHr = totalMin ~/ 60;
    final remainMin = totalMin % 60;
    final timeStr = totalHr > 0 ? '${totalHr}h ${remainMin}m' : '${totalMin}m';

    return Scaffold(
      backgroundColor: const Color(0xFF03020A),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.bar_chart_rounded, color: Color(0xFF6C63FF), size: 24),
                const SizedBox(width: 10),
                Text(l.statsTitle, style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 2)),
              ]),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // ── Seviye kartı ──
                  _LevelCard(level: gs.level, xp: gs.xp, xpNext: gs.xpForNextLevel, progress: gs.xpProgress),

                  const SizedBox(height: 16),

                  // ── Günlük görevler ──
                  _SectionTitle(title: l.dailyQuests),
                  const SizedBox(height: 10),
                  ...gs.dailyQuests.map((q) => _QuestTile(quest: q)),

                  const SizedBox(height: 20),

                  // ── Genel istatistikler ──
                  _SectionTitle(title: l.statsGeneral),
                  const SizedBox(height: 10),

                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.speed, color: const Color(0xFFFF5722),
                      label: 'RPM', value: gs.formattedRpm,
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      icon: Icons.timer, color: const Color(0xFF2196F3),
                      label: l.statsPlayTime, value: timeStr,
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.login, color: const Color(0xFF4CAF50),
                      label: l.statsSessions, value: '${gs.totalSessions}',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      icon: Icons.military_tech, color: const Color(0xFFFFD700),
                      label: l.statsBadges, value: '${gs.earnedBadges.length}/${GameState.badges.length}',
                    )),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _StatCard(
                      icon: Icons.bubble_chart, color: const Color(0xFFFF006E),
                      label: l.statsBalloons, value: '${gs.totalBalloonsPop}',
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: _StatCard(
                      icon: Icons.broken_image, color: const Color(0xFF00BCD4),
                      label: l.statsGlass, value: '${gs.totalGlassSmash}',
                    )),
                  ]),

                  const SizedBox(height: 20),

                  // ── Mod kullanımı ──
                  if (gs.modePlayCounts.isNotEmpty) ...[
                    _SectionTitle(title: l.statsModePlays),
                    const SizedBox(height: 10),
                    ...gs.modePlayCounts.entries.map((e) => _ModeTile(name: e.key, count: e.value)),
                  ],

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final int level;
  final double xp;
  final double xpNext;
  final double progress;
  const _LevelCard({required this.level, required this.xp, required this.xpNext, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [
            const Color(0xFF6C63FF).withValues(alpha: 0.15),
            const Color(0xFF6C63FF).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6C63FF).withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(colors: [Color(0xFF6C63FF), Color(0xFF3F37A1)]),
                boxShadow: [BoxShadow(color: const Color(0xFF6C63FF).withValues(alpha: 0.4), blurRadius: 15)],
              ),
              alignment: Alignment.center,
              child: Text('$level', style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Level $level', style: const TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${xp.toStringAsFixed(0)} / ${xpNext.toStringAsFixed(0)} XP',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              ],
            )),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF6C63FF)),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: TextStyle(
      color: Colors.white.withValues(alpha: 0.5), fontSize: 13,
      fontWeight: FontWeight.w700, letterSpacing: 2));
  }
}

class _QuestTile extends StatelessWidget {
  final DailyQuest quest;
  const _QuestTile({required this.quest});

  String _formatProgress(DailyQuest q) {
    if (q.type == QuestType.playTime) {
      // Saniye -> dakika
      final progMin = (q.progress / 60).floor();
      final targetMin = (q.target / 60).floor();
      return '$progMin/$targetMin';
    }
    return '${q.progress.clamp(0, q.target).toStringAsFixed(0)}/${q.target.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final progress = (quest.progress / quest.target).clamp(0.0, 1.0);
    final questName = quest.getName(l);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: quest.completed
            ? const Color(0xFF4CAF50).withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: quest.completed
            ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(children: [
        Text(quest.completed ? '✅' : quest.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(questName,
              style: TextStyle(
                color: quest.completed ? Colors.white70 : Colors.white54,
                fontSize: 14, fontWeight: FontWeight.w700,
                decoration: quest.completed ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                valueColor: AlwaysStoppedAnimation(quest.completed
                    ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
                    : const Color(0xFFFF9800).withValues(alpha: 0.6)),
                minHeight: 4,
              ),
            ),
          ],
        )),
        const SizedBox(width: 10),
        Text(_formatProgress(quest),
          style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCard({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.withValues(alpha: 0.7), size: 22),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  final String name;
  final int count;
  const _ModeTile({required this.name, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Text(name, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        const Spacer(),
        Text('$count', style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
