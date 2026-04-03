import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'spinner_collection.dart';
import 'l10n/app_localizations.dart';

class CollectionScreen extends StatefulWidget {
  final double allTimeMaxRpm;
  final String selectedId;
  final void Function(SpinnerModel) onSelect;

  const CollectionScreen({
    super.key,
    required this.allTimeMaxRpm,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  Set<String> _unlockedIds = {'classic_red', 'steel_blue', 'dark_steel'};

  @override
  void initState() {
    super.initState();
    _loadUnlocked();
    _checkUnlocks();
  }

  Future<void> _loadUnlocked() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('unlocked_spinners');
    if (saved != null) {
      setState(() => _unlockedIds = saved.toSet());
    }
  }

  Future<void> _checkUnlocks() async {
    final prefs = await SharedPreferences.getInstance();
    final Set<String> newUnlocks = {..._unlockedIds};
    final rpm = widget.allTimeMaxRpm;

    for (final s in SpinnerCollection.all) {
      if (!s.locked) {
        newUnlocks.add(s.id);
        continue;
      }
      if (s.id == 'gold_tri' && rpm >= 100) newUnlocks.add(s.id);
      if (s.id == 'neon_5' && rpm >= 200) newUnlocks.add(s.id);
      if (s.id == 'rose_gold' && rpm >= 250) newUnlocks.add(s.id);
      if (s.id == 'holo_6' && rpm >= 300) newUnlocks.add(s.id);
      if (s.id == 'galaxy' && rpm >= 350) newUnlocks.add(s.id);
    }

    if (newUnlocks.length != _unlockedIds.length) {
      await prefs.setStringList('unlocked_spinners', newUnlocks.toList());
      setState(() => _unlockedIds = newUnlocks);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(child: _buildGrid()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white54),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            AppLocalizations.of(context)?.collectionTitle ?? 'KOLEKSiYON',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const Spacer(),
          Text(
            '${_unlockedIds.length}/${SpinnerCollection.all.length}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: SpinnerCollection.all.length,
      itemBuilder: (_, i) => _buildCard(SpinnerCollection.all[i]),
    );
  }

  Widget _buildCard(SpinnerModel s) {
    final unlocked = _unlockedIds.contains(s.id);
    final selected = widget.selectedId == s.id;
    final colors = s.skin.colors;

    return GestureDetector(
      onTap: () {
        if (!unlocked) {
          final l = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l != null
                  ? l.collectionUnlock(s.localizedUnlockHint(context))
                  : 'Kilit acmak icin: ${s.unlockHint}'),
              backgroundColor: const Color(0xFF1E1E3F),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
        }
        widget.onSelect(s);
        Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: unlocked
                ? [
                    colors[0].withValues(alpha: 0.15),
                    colors[1].withValues(alpha: 0.08),
                  ]
                : [Colors.white.withValues(alpha: 0.03), Colors.white.withValues(alpha: 0.01)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? colors[0]
                : unlocked
                    ? colors[0].withValues(alpha: 0.3)
                    : Colors.white12,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Spinner önizleme
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(s.emoji, style: const TextStyle(fontSize: 52)),
                  if (!unlocked)
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: const Icon(Icons.lock,
                          color: Colors.white54, size: 28),
                    ),
                  if (selected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: colors[0],
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 12),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                s.localizedName(context),
                style: TextStyle(
                  color: unlocked ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context)?.collectionInfo(s.arms, s.skin.localizedLabel(context)) ??
                    '${s.arms} kol · ${s.skin.label}',
                style: TextStyle(
                  color: unlocked ? colors[0].withValues(alpha: 0.8) : Colors.white24,
                  fontSize: 11,
                ),
              ),
              if (!unlocked) ...[
                const SizedBox(height: 6),
                Text(
                  s.localizedUnlockHint(context),
                  style:
                      const TextStyle(color: Colors.white30, fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
