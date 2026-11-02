import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/l10n/game_text.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('HJKL directions agree with WASD and opposite inputs cancel', () {
    final run = RunState()..start();
    final game = RuntimeGame(run);
    for (final entry in {
      LogicalKeyboardKey.keyH: [-1.0, 0.0],
      LogicalKeyboardKey.keyJ: [0.0, 1.0],
      LogicalKeyboardKey.keyK: [0.0, -1.0],
      LogicalKeyboardKey.keyL: [1.0, 0.0],
    }.entries) {
      game.onKeyEvent(
        KeyDownEvent(
          timeStamp: Duration.zero,
          logicalKey: entry.key,
          physicalKey: PhysicalKeyboardKey.keyH,
        ),
        {entry.key},
      );
      expect(run.movement.x, entry.value[0]);
      expect(run.movement.y, entry.value[1]);
    }
    game.onKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        logicalKey: LogicalKeyboardKey.keyH,
        physicalKey: PhysicalKeyboardKey.keyH,
      ),
      {LogicalKeyboardKey.keyH, LogicalKeyboardKey.keyD},
    );
    expect(run.movement.length2, 0);
    game.inputBlocked = true;
    run.pause();
    game.onKeyEvent(
      const KeyDownEvent(
        timeStamp: Duration.zero,
        logicalKey: LogicalKeyboardKey.keyP,
        physicalKey: PhysicalKeyboardKey.keyP,
      ),
      {LogicalKeyboardKey.keyP},
    );
    expect(run.phase, RunPhase.paused);
  });

  test(
    'language, audio and discovery records survive settings reload',
    () async {
      SharedPreferences.setMockInitialValues({});
      final first = GameSettings();
      await first.load();
      first.update(language: 'en', muted: true, volume: 0.6);
      first.discover(['enemy.0', 'upgrade.concurrency']);
      // Reload only after the ordered preference writes have reached storage.
      await first.flush();
      final second = GameSettings();
      await second.load();
      expect(second.language, 'en');
      expect(second.muted, isTrue);
      expect(second.volume, 0.6);
      expect(
        second.discoveries,
        containsAll(['enemy.0', 'upgrade.concurrency']),
      );
      first.dispose();
      second.dispose();
    },
  );

  test('all copy has matching nonempty Japanese and English placeholders', () {
    final placeholder = RegExp(r'\{\w+\}');
    for (final entry in GameText.copy.entries) {
      expect(entry.value.length, 2, reason: entry.key);
      expect(
        entry.value.every((s) => s.trim().isNotEmpty),
        isTrue,
        reason: entry.key,
      );
      final ja = placeholder
          .allMatches(entry.value[0])
          .map((m) => m[0])
          .toSet();
      final en = placeholder
          .allMatches(entry.value[1])
          .map((m) => m[0])
          .toSet();
      expect(ja, en, reason: entry.key);
    }
  });
}
