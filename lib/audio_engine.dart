import 'package:just_audio/just_audio.dart';

/// Ses motoru: ambient.wav (sürekli rahatlatıcı müzik) + click.mp3 (dokunma).
class AudioEngine {
  // Singleton
  static final AudioEngine _instance = AudioEngine._();
  static AudioEngine get instance => _instance;
  AudioEngine._();
  factory AudioEngine() => _instance;

  AudioPlayer? _ambientPlayer;
  AudioPlayer? _clickPlayer;

  bool _ready = false;
  bool _clickBusy = false;
  bool _muted = false;

  bool get isMuted => _muted;

  Future<void> init() async {
    try {
      final ambient = AudioPlayer();
      await ambient.setAsset('assets/audio/sigmamusicart-meditation-yoga-relaxing-music-380330.mp3');
      await ambient.setLoopMode(LoopMode.one);
      await ambient.setVolume(0.40);
      ambient.play();
      _ambientPlayer = ambient;

      final click = AudioPlayer();
      await click.setAsset('assets/audio/click.mp3');
      await click.setVolume(0.7);
      _clickPlayer = click;

      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  void toggleMute() {
    _muted = !_muted;
    if (_muted) {
      _ambientPlayer?.setVolume(0.0);
      _clickPlayer?.setVolume(0.0);
    } else {
      _ambientPlayer?.setVolume(0.40);
      _clickPlayer?.setVolume(0.7);
    }
  }

  /// RPM bazlı güncelleme artık gerekmiyor — ambient sabit çalıyor.
  void update(double rpm) {
    // no-op: ambient music plays at constant volume
  }

  void playTouch() {
    final player = _clickPlayer;
    if (!_ready || player == null || _clickBusy || _muted) return;
    _clickBusy = true;
    player.seek(Duration.zero).then((_) {
      return player.play();
    }).then((_) {
      _clickBusy = false;
    }).catchError((_) {
      _clickBusy = false;
    });
  }

  void pause() {
    _ambientPlayer?.pause();
  }

  void resume() {
    if (!_muted) _ambientPlayer?.play();
  }

  void dispose() {
    _ambientPlayer?.dispose();
    _clickPlayer?.dispose();
  }
}
