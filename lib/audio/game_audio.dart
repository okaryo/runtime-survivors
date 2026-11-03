import 'sound_backend_stub.dart'
    if (dart.library.js_interop) 'sound_backend_web.dart';
import 'sound_cue.dart';
import 'audio_output.dart';
import 'victory_fanfare.dart';

class GameAudio {
  GameAudio({AudioOutput? output}) : _backend = output ?? SoundBackend();
  final AudioOutput _backend;
  bool _musicWanted = false;
  final _clock = Stopwatch()..start();
  final Map<SoundCue, int> _lastPlayed = {};
  bool muted = false;
  double volume = 1.0;

  void configure({required bool muted, required double volume}) {
    this.muted = muted;
    this.volume = volume;
    _backend.setVolume(muted ? 0 : volume);
    _syncMusic();
  }

  // Call only from a click/key gesture, so browsers can unlock Web Audio.
  void unlock() => _backend.unlock();

  void setMusicPlaying(bool playing) {
    _musicWanted = playing;
    _syncMusic();
  }

  void _syncMusic() =>
      _backend.setMusicPlaying(_musicWanted && !muted && volume > 0);
  void restartMusic() => _backend.restartMusic();

  void play(SoundCue cue) {
    if (muted || volume <= 0) return;
    final now = _clock.elapsedMilliseconds;
    final cooldown = switch (cue) {
      SoundCue.kill => 90,
      SoundCue.pickup => 100,
      SoundCue.hit => 150,
      _ => 50,
    };
    if (now - (_lastPlayed[cue] ?? -1000) < cooldown) return;
    _lastPlayed[cue] = now;
    if (cue == SoundCue.victory) {
      for (final tone in victoryFanfare) {
        _backend.note(
          tone.frequency,
          tone.offset,
          tone.duration,
          'triangle',
          endFrequencyRatio: 1,
          hold: tone.hold,
        );
      }
      return;
    }
    final notes = switch (cue) {
      SoundCue.start => [330.0, 440.0, 660.0],
      SoundCue.hit => [100.0, 70.0],
      SoundCue.kill => [220.0],
      SoundCue.pickup => [880.0],
      SoundCue.levelUp => [440.0, 554.0, 660.0, 880.0],
      SoundCue.select => [550.0, 825.0],
      SoundCue.end => [330.0, 220.0, 165.0],
      SoundCue.warning => [180.0, 180.0, 240.0],
      SoundCue.pulse => [130.0, 260.0],
      SoundCue.collection => [520.0, 260.0, 130.0],
      SoundCue.victory =>
        const <double>[], // Handled by the musical score above.
    };
    for (var i = 0; i < notes.length; i++) {
      _backend.note(
        notes[i],
        i * 0.075,
        cue == SoundCue.pickup ? 0.07 : 0.13,
        cue == SoundCue.hit || cue == SoundCue.warning ? 'square' : 'triangle',
      );
    }
  }

  void dispose() => _backend.dispose();
}
