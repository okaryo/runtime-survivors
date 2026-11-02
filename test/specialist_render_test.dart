import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  testWidgets(
    'all six task silhouettes, locked aim, summon warning and both projectile teams render safely',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final run = RunState()
        ..start(policy: TypingPolicy.dynamicTyping)
        ..enemies.clear();
      for (var kind = 0; kind < 6; kind++) {
        final enemy = TaskEnemy(
          Vector2((kind % 3 - 1) * 180, kind < 3 ? -130 : 130),
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
        LinearProjectile(
          Vector2(70, 30),
          Vector2(640, 0),
          damage: 42,
          hostile: false,
        ),
      ]);
      run.phase = RunPhase.paused;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: key,
            child: GameWidget(game: RuntimeGame(run)),
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
