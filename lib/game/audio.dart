import 'package:flame_audio/flame_audio.dart';

/// Sound effects. Browsers only allow audio after the player interacts,
/// so nothing loads or plays until [init] is called from an input handler.
class Sfx {
  static const _files = [
    'jump.wav', 'land.wav', 'hit.wav', 'boom.wav', 'creak.wav', 'lucky.wav', 'shortcut.wav',
    'launch.wav', 'win.wav', 'lose.wav', 'debris.wav', 'rumble.wav',
  ];

  bool _started = false;
  bool muted = false;
  AudioPlayer? _rumble;
  double _rumbleVol = -1;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    try {
      await FlameAudio.audioCache.loadAll(_files);
      _rumble = await FlameAudio.loop('rumble.wav', volume: muted ? 0 : 0.15);
    } catch (_) {
      // Audio is optional; the game plays fine without it.
    }
  }

  void toggleMute() {
    muted = !muted;
    _rumbleVol = -1;
    rumble(0);
  }

  /// Sets the background rumble, which swells during quakes.
  void rumble(double quake) {
    final v = muted ? 0.0 : (0.12 + quake * 0.2).clamp(0.0, 0.6);
    if ((v - _rumbleVol).abs() < 0.04) return;
    _rumbleVol = v;
    try {
      _rumble?.setVolume(v);
    } catch (_) {}
  }

  Future<void> _play(String name, double volume) async {
    if (!_started || muted) return;
    try {
      await FlameAudio.play(name, volume: volume);
    } catch (_) {}
  }

  void jump() => _play('jump.wav', 0.3);
  void land() => _play('land.wav', 0.4);
  void hit() => _play('hit.wav', 0.6);
  void boom() => _play('boom.wav', 0.7);
  void creak() => _play('creak.wav', 0.25);
  void lucky() => _play('lucky.wav', 0.35);
  void shortcut() => _play('shortcut.wav', 0.7);
  void launch() => _play('launch.wav', 0.8);
  void win() => _play('win.wav', 0.5);
  void lose() => _play('lose.wav', 0.5);
  void debris() => _play('debris.wav', 0.3);
}
