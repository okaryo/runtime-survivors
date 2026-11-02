import 'package:flutter_test/flutter_test.dart';
import 'package:flame/components.dart';
import 'package:runtime_survivors/audio/audio_output.dart';
import 'package:runtime_survivors/audio/game_audio.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';

class RecordingOutput implements AudioOutput {
  bool playing = false;
  bool disposed = false;
  double volume = 1;
  int restarts = 0;
  @override
  void unlock() {}
  @override
  void setVolume(double value) => volume = value;
  @override
  void note(double frequency, double offset, double duration, String wave) {}
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
