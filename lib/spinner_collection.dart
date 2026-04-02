import 'package:flutter/material.dart';

/// Spinner modeli — şekil + kaplama bilgisi
class SpinnerModel {
  final String id;
  final String name;
  final String emoji;
  final int arms;          // Kol sayısı
  final SpinnerSkin skin;
  final bool locked;
  final String unlockHint;

  const SpinnerModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.arms,
    required this.skin,
    this.locked = false,
    this.unlockHint = '',
  });
}

enum SpinnerSkin {
  metalRed,
  metalBlue,
  metalGold,
  neonGreen,
  holographic,
  darkSteel,
  rose,
  galaxy,
}

extension SpinnerSkinColors on SpinnerSkin {
  List<Color> get colors {
    switch (this) {
      case SpinnerSkin.metalRed:
        return [const Color(0xFFE53935), const Color(0xFF8B0000)];
      case SpinnerSkin.metalBlue:
        return [const Color(0xFF1E88E5), const Color(0xFF0D47A1)];
      case SpinnerSkin.metalGold:
        return [const Color(0xFFFFD700), const Color(0xFFFF8F00)];
      case SpinnerSkin.neonGreen:
        return [const Color(0xFF00E676), const Color(0xFF00796B)];
      case SpinnerSkin.holographic:
        return [const Color(0xFFE040FB), const Color(0xFF00BCD4)];
      case SpinnerSkin.darkSteel:
        return [const Color(0xFF607D8B), const Color(0xFF263238)];
      case SpinnerSkin.rose:
        return [const Color(0xFFE91E63), const Color(0xFF9C27B0)];
      case SpinnerSkin.galaxy:
        return [const Color(0xFF3F51B5), const Color(0xFF7B1FA2)];
    }
  }

  String get label {
    switch (this) {
      case SpinnerSkin.metalRed: return 'Kırmızı Metal';
      case SpinnerSkin.metalBlue: return 'Mavi Metal';
      case SpinnerSkin.metalGold: return 'Altın';
      case SpinnerSkin.neonGreen: return 'Neon';
      case SpinnerSkin.holographic: return 'Holografik';
      case SpinnerSkin.darkSteel: return 'Çelik';
      case SpinnerSkin.rose: return 'Rose';
      case SpinnerSkin.galaxy: return 'Galaksi';
    }
  }
}

/// Tüm spinner koleksiyonu
class SpinnerCollection {
  static const List<SpinnerModel> all = [
    SpinnerModel(
      id: 'classic_red',
      name: 'Klasik',
      emoji: '🔴',
      arms: 8,
      skin: SpinnerSkin.metalRed,
    ),
    SpinnerModel(
      id: 'steel_blue',
      name: 'Çelik Mavi',
      emoji: '🔵',
      arms: 8,
      skin: SpinnerSkin.metalBlue,
    ),
    SpinnerModel(
      id: 'gold_tri',
      name: 'Altın Üçlü',
      emoji: '⭐',
      arms: 3,
      skin: SpinnerSkin.metalGold,
      locked: true,
      unlockHint: '100 RPM kır',
    ),
    SpinnerModel(
      id: 'neon_5',
      name: 'Neon 5',
      emoji: '💚',
      arms: 5,
      skin: SpinnerSkin.neonGreen,
      locked: true,
      unlockHint: '200 RPM kır',
    ),
    SpinnerModel(
      id: 'holo_6',
      name: 'Hologram',
      emoji: '🌈',
      arms: 6,
      skin: SpinnerSkin.holographic,
      locked: true,
      unlockHint: '300 RPM kır',
    ),
    SpinnerModel(
      id: 'dark_steel',
      name: 'Karanlık',
      emoji: '⚙️',
      arms: 8,
      skin: SpinnerSkin.darkSteel,
    ),
    SpinnerModel(
      id: 'rose_gold',
      name: 'Rose Gold',
      emoji: '🌸',
      arms: 5,
      skin: SpinnerSkin.rose,
      locked: true,
      unlockHint: '250 RPM kır',
    ),
    SpinnerModel(
      id: 'galaxy',
      name: 'Galaksi',
      emoji: '🌌',
      arms: 6,
      skin: SpinnerSkin.galaxy,
      locked: true,
      unlockHint: '350 RPM kır',
    ),
  ];
}
