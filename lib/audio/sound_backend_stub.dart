import 'audio_output.dart';

// Native tests and future non-Web targets run silently.
class SoundBackend implements AudioOutput {
  @override
  void unlock() {}
  @override
  void setVolume(double value) {}
  @override
  void note(
    double frequency,
    double offset,
    double duration,
    String wave, {
    double endFrequencyRatio = 0.75,
    double hold = 0,
  }) {}
  @override
  void setMusicPlaying(bool playing) {}
  @override
  void restartMusic() {}
  @override
  void dispose() {}
}
