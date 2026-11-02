// Native tests and future non-Web targets run silently.
class SoundBackend {
  void unlock() {}
  void setVolume(double value) {}
  void note(double frequency, double offset, double duration, String wave) {}
  void dispose() {}
}
