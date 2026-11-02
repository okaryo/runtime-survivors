import 'dart:js_interop';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'audio_output.dart';

import 'package:web/web.dart' as web;

/// Synthesized effects: no remote audio, downloads or asset licensing needed.
class SoundBackend implements AudioOutput {
  web.AudioContext? _context;
  web.GainNode? _master;
  double _volume = 1.0;
  bool _disposed = false;
  bool _musicWanted = false;
  bool _loadingMusic = false;
  web.AudioBuffer? _musicBuffer;
  web.AudioBufferSourceNode? _musicSource;
  web.GainNode? _musicEnvelope;
  double _musicOffset = 0;
  double _musicStartedAt = 0;

  @override
  void unlock() {
    if (_disposed) return;
    final context = _context ??= web.AudioContext();
    if (_master == null) {
      _master = context.createGain();
      _master!.gain.value = _volume;
      _master!.connect(context.destination);
    }
    if (context.state == 'suspended') {
      unawaited(_resume(context));
    }
    _ensureMusic();
    _syncMusic();
  }

  @override
  void setVolume(double value) {
    _volume = value;
    final context = _context;
    if (context != null) {
      _master?.gain.setTargetAtTime(value, context.currentTime, 0.01);
    }
  }

  @override
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

  Future<void> _resume(web.AudioContext context) async {
    try {
      await context.resume().toDart;
      if (!_disposed) _syncMusic();
    } catch (_) {
      // A subsequent user gesture can retry a browser-blocked resume.
    }
  }

  @override
  void setMusicPlaying(bool playing) {
    _musicWanted = playing;
    if (playing) _ensureMusic();
    _syncMusic();
  }

  void _ensureMusic() {
    final context = _context;
    if (_disposed || context == null || _loadingMusic || _musicBuffer != null) {
      return;
    }
    _loadingMusic = true;
    unawaited(_loadMusic(context));
  }

  Future<void> _loadMusic(web.AudioContext context) async {
    try {
      final data = await rootBundle.load('assets/audio/runtime_loop.wav');
      if (_disposed) return;
      final bytes = Uint8List.fromList(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final buffer = await context.decodeAudioData(bytes.buffer.toJS).toDart;
      if (_disposed) return;
      _musicBuffer = buffer;
      _syncMusic();
    } catch (error) {
      if (!_disposed) debugPrint('Could not load runtime music: $error');
    } finally {
      _loadingMusic = false;
    }
  }

  void _syncMusic() {
    if (!_musicWanted || _disposed) {
      _stopMusic();
      return;
    }
    final context = _context;
    final buffer = _musicBuffer;
    final master = _master;
    if (context == null ||
        buffer == null ||
        master == null ||
        context.state != 'running' ||
        _musicSource != null) {
      return;
    }
    final source = context.createBufferSource()
      ..buffer = buffer
      ..loop = true;
    final envelope = context.createGain();
    final now = context.currentTime;
    envelope.gain.setValueAtTime(0, now);
    envelope.gain.linearRampToValueAtTime(0.36, now + 0.025);
    source.connect(envelope);
    envelope.connect(master);
    source.onended = ((web.Event _) {
      source.disconnect();
      envelope.disconnect();
    }).toJS;
    _musicSource = source;
    _musicEnvelope = envelope;
    _musicStartedAt = now;
    source.start(now, _musicOffset);
  }

  void _stopMusic() {
    final source = _musicSource;
    final context = _context;
    if (source == null || context == null) return;
    _musicOffset =
        (_musicOffset + context.currentTime - _musicStartedAt) %
        _musicBuffer!.duration;
    final envelope = _musicEnvelope!;
    _musicSource = null;
    _musicEnvelope = null;
    final now = context.currentTime;
    envelope.gain.cancelScheduledValues(now);
    envelope.gain.setTargetAtTime(0, now, 0.005);
    source.stop(_disposed ? now : now + 0.025);
  }

  @override
  void restartMusic() {
    _stopMusic();
    _musicOffset = 0;
    _syncMusic();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopMusic();
    _musicBuffer = null;
    final context = _context;
    _context = null;
    _master = null;
    if (context != null) {
      unawaited(context.close().toDart.catchError((_) => null));
    }
  }
}
