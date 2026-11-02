import 'dart:js_interop';
import 'dart:async';

import 'package:web/web.dart' as web;

/// Synthesized effects: no remote audio, downloads or asset licensing needed.
class SoundBackend {
  web.AudioContext? _context;
  web.GainNode? _master;
  double _volume = 1.0;
  bool _disposed = false;

  void unlock() {
    if (_disposed) return;
    final context = _context ??= web.AudioContext();
    if (_master == null) {
      _master = context.createGain();
      _master!.gain.value = _volume;
      _master!.connect(context.destination);
    }
    if (context.state == 'suspended') {
      unawaited(context.resume().toDart.catchError((_) => null));
    }
  }

  void setVolume(double value) {
    _volume = value;
    final context = _context;
    if (context != null) {
      _master?.gain.setTargetAtTime(value, context.currentTime, 0.01);
    }
  }

  void note(double frequency, double offset, double duration, String wave) {
    final context = _context;
    final master = _master;
    if (_disposed ||
        context == null ||
        master == null ||
        context.state != 'running') {
      return;
    }
    final oscillator = context.createOscillator()..type = wave;
    final envelope = context.createGain();
    final start = context.currentTime + offset;
    oscillator.frequency.setValueAtTime(frequency, start);
    oscillator.frequency.exponentialRampToValueAtTime(
      frequency * 0.75,
      start + duration,
    );
    envelope.gain.setValueAtTime(0.0001, start);
    envelope.gain.exponentialRampToValueAtTime(0.16, start + 0.005);
    envelope.gain.exponentialRampToValueAtTime(0.0001, start + duration);
    oscillator.connect(envelope);
    envelope.connect(master);
    oscillator.onended = ((web.Event _) {
      oscillator.disconnect();
      envelope.disconnect();
    }).toJS;
    oscillator.start(start);
    oscillator.stop(start + duration + 0.01);
  }

  void dispose() {
    _disposed = true;
    final context = _context;
    _context = null;
    _master = null;
    if (context != null) {
      unawaited(context.close().toDart.catchError((_) => null));
    }
  }
}
