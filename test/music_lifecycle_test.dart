import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:runtime_survivors/audio/audio_output.dart';
import 'package:runtime_survivors/audio/game_audio.dart';
import 'package:runtime_survivors/audio/sound_cue.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';

class RecordingOutput implements AudioOutput {
  bool playing = false;
  bool disposed = false;
  double volume = 1;
  int restarts = 0;
  final notes =
      <
        ({
          double frequency,
          double offset,
          double duration,
          double endFrequencyRatio,
          double hold,
          String wave,
        })
      >[];
  @override
  void unlock() {}
  @override
  void setVolume(double value) => volume = value;
  @override
  void note(
    double frequency,
    double offset,
    double duration,
    String wave, {
    double endFrequencyRatio = 0.75,
    double hold = 0,
  }) => notes.add((
    frequency: frequency,
    offset: offset,
    duration: duration,
    endFrequencyRatio: endFrequencyRatio,
    hold: hold,
    wave: wave,
  ));
  @override
  void setMusicPlaying(bool value) => playing = value;
  @override
  void restartMusic() => restarts++;
  @override
  void dispose() {
    disposed = true;
    playing = false;
  }
}

void main() {
  test(
    'victory emits a distinct audible fanfare after the battle music stops',
    () {
      final output = RecordingOutput();
      final audio = GameAudio(output: output);
      final run = RunState()
        ..start()
        ..elapsed = 299.99;
      final game = RuntimeGame(run)
        ..onSound = audio.play
        ..onPhaseChanged = (phase) =>
            audio.setMusicPlaying(phase == RunPhase.running);
      game.onGameResize(Vector2(1280, 720));
      game.refresh();
      output.notes.clear();
      game.update(0.02);
      expect(run.phase, RunPhase.won);
      expect(output.playing, isFalse);
      expect(output.notes.length, 7);
      expect(output.notes.every((note) => note.endFrequencyRatio == 1), isTrue);
      expect(output.notes.every((note) => note.wave == 'triangle'), isTrue);
      final melody = output.notes.take(3).toList();
      expect(melody[1].frequency, greaterThan(melody[0].frequency));
      expect(melody[2].frequency, greaterThan(melody[1].frequency));
      final chord = output.notes.skip(3).toList();
      expect(chord.map((note) => note.offset).toSet().length, 1);
      expect(chord.every((note) => note.hold > 0), isTrue);
      final root = chord.first.frequency;
      expect(chord[1].frequency / root, closeTo(1.2599, 0.001)); // Major third.
      expect(chord[2].frequency / root, closeTo(1.4983, 0.001)); // Fifth.
      expect(chord.last.frequency / root, closeTo(2, 0.001));
      expect(
        output.notes.last.offset + output.notes.last.duration,
        greaterThan(1.5),
      );
      output.notes.clear();
      audio.configure(muted: true, volume: 1);
      audio.play(SoundCue.victory);
      expect(output.notes, isEmpty);
      audio.dispose();
    },
  );
  test('impact effects keep their falling pitch', () {
    final output = RecordingOutput();
    final audio = GameAudio(output: output);
    audio.play(SoundCue.hit);
    expect(
      output.notes.every((note) => note.endFrequencyRatio == 0.75),
      isTrue,
    );
    expect(output.notes.last.frequency, lessThan(output.notes.first.frequency));
    output.notes.clear();
    audio.configure(muted: false, volume: 0);
    audio.play(SoundCue.victory);
    expect(output.notes, isEmpty);
    audio.dispose();
  });
  test('lethal damage plays a descending minor theme once and stops music', () {
    final output = RecordingOutput();
    final audio = GameAudio(output: output);
    final run = RunState()..start();
    final game = RuntimeGame(run)
      ..onSound = audio.play
      ..onPhaseChanged = (phase) =>
          audio.setMusicPlaying(phase == RunPhase.running);
    game.onGameResize(Vector2(1280, 720));
    game.refresh();
    expect(output.playing, isTrue);
    output.notes.clear();
    run.health = 1;
    run.enemies
      ..clear()
      ..add(TaskEnemy(Vector2.zero(), health: 100000));
    game.update(0.02);
    expect(run.phase, RunPhase.lost);
    expect(output.playing, isFalse);
    final theme = output.notes
        .where((note) => note.endFrequencyRatio == 1)
        .toList();
    expect(theme.length, 7);
    expect(theme.every((note) => note.wave == 'triangle'), isTrue);
    expect(theme[1].frequency, lessThan(theme[0].frequency));
    expect(theme[2].frequency, lessThan(theme[1].frequency));
    expect(theme[1].offset - theme[0].offset, greaterThan(0.2));
    final chord = theme.skip(3).toList();
    expect(chord.map((note) => note.offset).toSet().length, 1);
    expect(chord.every((note) => note.hold > 0), isTrue);
    final root = chord.first.frequency;
    expect(chord[1].frequency / root, closeTo(1.1892, 0.001)); // Minor third.
    expect(chord[2].frequency / root, closeTo(1.4983, 0.001));
    expect(chord.last.frequency / root, 2);
    expect(theme.last.offset + theme.last.duration, greaterThan(2.2));
    final count = output.notes.length;
    game.update(0.05);
    game.refresh();
    expect(output.notes.length, count);
    audio.dispose();
  });
  test('game-over theme respects mute and zero volume', () {
    final output = RecordingOutput();
    final audio = GameAudio(output: output);
    audio.configure(muted: true, volume: 1);
    audio.play(SoundCue.end);
    expect(output.notes, isEmpty);
    audio.configure(muted: false, volume: 0);
    audio.play(SoundCue.end);
    expect(output.notes, isEmpty);
    audio.dispose();
  });
  test(
    'music follows start, level selection, pause, resume, victory and defeat',
    () {
      final output = RecordingOutput();
      final audio = GameAudio(output: output);
      final run = RunState();
      final game = RuntimeGame(run)
        ..onPhaseChanged = (phase) =>
            audio.setMusicPlaying(phase == RunPhase.running);
      game.onGameResize(Vector2(1280, 720));
      game.refresh();
      expect(output.playing, isFalse);
      audio.restartMusic();
      run.start();
      game.refresh();
      expect(output.playing, isTrue);
      expect(output.restarts, 1);
      run.addExperience(run.nextLevelXp);
      game.refresh();
      expect(output.playing, isFalse);
      run.choose(run.choices.first);
      game.refresh();
      expect(output.playing, isTrue);
      run.pause();
      game.refresh();
      expect(output.playing, isFalse);
      run.resume();
      game.refresh();
      expect(output.playing, isTrue);
      run.elapsed = 299.99;
      game.update(0.02);
      expect(run.phase, RunPhase.won);
      expect(output.playing, isFalse);
      run.start();
      game.refresh();
      expect(output.playing, isTrue);
      run.phase = RunPhase.lost;
      game.refresh();
      expect(output.playing, isFalse);
      audio.dispose();
      expect(output.disposed, isTrue);
    },
  );

  test('mute and zero volume suppress music; unmute obeys paused state', () {
    final output = RecordingOutput();
    final audio = GameAudio(output: output);
    audio.setMusicPlaying(true);
    expect(output.playing, isTrue);
    audio.configure(muted: true, volume: 1);
    expect(output.playing, isFalse);
    expect(output.volume, 0);
    audio.configure(muted: false, volume: 0);
    expect(output.playing, isFalse);
    audio.configure(muted: false, volume: 0.7);
    expect(output.playing, isTrue);
    expect(output.volume, 0.7);
    audio.setMusicPlaying(false);
    audio.configure(muted: true, volume: 1);
    audio.configure(muted: false, volume: 1);
    expect(output.playing, isFalse);
    audio.dispose();
  });
}
