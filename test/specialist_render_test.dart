import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/game/ability_runtime.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  testWidgets(
    'all task silhouettes, auras, slow fields, hazards and both projectile teams render safely',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final run = RunState()
        ..start()
        ..enemies.clear();
      for (var kind = 0; kind < EnemyType.values.length; kind++) {
        final enemy = TaskEnemy(
          Vector2((kind % 4 - 1.5) * 210 + 70, (kind ~/ 4 - 1) * 160),
          kind: kind,
        );
        if (kind >= 3) {
          enemy.telegraphRemaining = 0.8;
          enemy.chargeDirection.setValues(1, -0.25);
        }
        run.enemies.add(enemy);
      }
      run.upgrades[Upgrade.nullSafety] = 1;
      run.projectiles.addAll([
        LinearProjectile(Vector2(-80, -30), Vector2(180, 0), damage: 11),
        LinearProjectile(Vector2(-100, 25), Vector2(180, 0), damage: 11),
        LinearProjectile(
          Vector2(70, 30),
          Vector2(640, 0),
          damage: 42,
          hostile: false,
        ),
      ]);
      run.hazards.add(DangerZone(Vector2(-220, 80))..remaining = 0.6);
      run.abilities.fields.add(SlowField(Vector2(-170, -60), 110, 0.7));
      run.abilities.fields.add(
        SlowField(Vector2(180, 80), 110, 0.7)..triggered = true,
      );
      run.instructions.add(
        Instruction(
          Vector2(-10, -70),
          run.enemies.last,
          54,
          kind: InstructionKind.cached,
        ),
      );
      run.upgrades[Upgrade.jitCompilation] = 1;
      run.upgrades[Upgrade.memoization] = 1;
      run.abilities.jitCharge = 75;
      run.phase = RunPhase.paused;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: GameWidget(
              game: RuntimeGame(run)..text = const GameText('en'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      if (Platform.environment['RUNTIME_CAPTURE'] == '1') {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.png,
          ))!;
          await File('/tmp/runtime-expanded-combat.png')
              .writeAsBytes(bytes.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
}
