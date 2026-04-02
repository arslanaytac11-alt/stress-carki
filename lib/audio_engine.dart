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
      _ambientPlayer = AudioPlayer();
      await _ambientPlayer!.setAsset('assets/audio/sigmamusicart-meditation-yoga-relaxing-music-380330.mp3');
      await _ambientPlayer!.setLoopMode(LoopMode.one);
      await _ambientPlayer!.setVolume(0.40);
      _ambientPlayer!.play();

      _clickPlayer = AudioPlayer();
      await _clickPlayer!.setAsset('assets/audio/click.mp3');
      await _clickPlayer!.setVolume(0.7);

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
    if (!_ready || _clickPlayer == null || _clickBusy || _muted) return;
    _clickBusy = true;
    _clickPlayer!.seek(Duration.zero).then((_) {
      return _clickPlayer!.play();
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
