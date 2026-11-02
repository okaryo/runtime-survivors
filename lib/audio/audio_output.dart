/// Platform audio contract; injected in tests to verify lifecycle behavior.
abstract interface class AudioOutput {
  void unlock();
  void setVolume(double value);
  void note(double frequency, double offset, double duration, String wave);
  void setMusicPlaying(bool playing);
  void restartMusic();
  void dispose();
}
