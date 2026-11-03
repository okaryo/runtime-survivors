import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/game/deadlock_encounter.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  testWidgets(
    'blocky leaks, subscription setup and active stream, clock windup and open pulse render',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 620);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final run = RunState()
        ..start()
        ..enemies.clear();
      final leak = TaskEnemy(
        Vector2(-245, -40),
        kind: EnemyType.memoryLeak.index,
      );
      final core = TaskEnemy(
        Vector2(250, -55),
        kind: EnemyType.deadlock.index,
        health: 3000,
      );
      final encounter = DeadlockEncounter(core);
      run.enemies.addAll(encounter.rebuild(run.player));
      encounter.warningRemaining = 0;
      run.deadlocks.add(encounter);
      final target = encounter.nodes[1];
      final timer = TaskEnemy(
        Vector2(150, 60),
        kind: EnemyType.timerEvent.index,
      );
      final winding =
          TaskEnemy(Vector2(-70, -150), kind: EnemyType.timerEvent.index)
            ..telegraphRemaining = 0.45
            ..pulseGaps = [pi, 0.5];
      run.enemies.addAll([leak, core, timer, winding]);
      for (var pattern = 0; pattern < 3; pattern++) {
        run.leakPatches.add(
          MemoryLeakPatch(
            Vector2(-260 + pattern * 95.0, 75 + (pattern == 1 ? 65 : 0)),
            leak,
            pattern: pattern,
          )..age = 2,
        );
      }
      run.timerPulses.add(
        TimerPulse(timer.position.clone(), [-pi * 0.88, 0.7])
          ..radius = 160
          ..previousRadius = 157,
      );
      run.upgrades[Upgrade.asyncStream] = 1;
      run.upgrades[Upgrade.garbageCollection] = 1;
      run.upgrades[Upgrade.jitCompilation] = 3;
      run.abilities.jitCharge = 65;
      run.effects.add(
        RunEffect(run.player.clone(), collection: true, radius: run.gcRadius)
          ..life = 0.6,
      );
      run.abilities.stream.connect(target, 0.7);
      run.phase = RunPhase.paused;
      run.elapsed = 275.3;
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: boundaryKey,
            child: GameWidget(
              game: RuntimeGame(run)..text = const GameText('en'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      run.abilities.stream.preparation = 0;
      run.abilities.stream.flash = 0.1;
      await tester.pump(const Duration(milliseconds: 30));
      expect(tester.takeException(), isNull);
      if (Platform.environment['RUNTIME_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('/tmp/runtime-pressure-feedback.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
