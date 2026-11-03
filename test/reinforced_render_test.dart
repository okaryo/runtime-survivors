import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: ordinary and high-load silhouettes, health bars and larger hazards render',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 650);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final run = RunState()
          ..start()
          ..enemies.clear();
        for (final pair in [
          (EnemyType.rpc, Vector2(-330, -115)),
          (EnemyType.timerEvent, Vector2(105, -115)),
          (EnemyType.memoryLeak, Vector2(-330, 90)),
          (EnemyType.forkBomb, Vector2(105, 90)),
        ]) {
          for (final heavy in [false, true]) {
            final enemy = TaskEnemy(
              pair.$2 + Vector2(heavy ? 130 : 0, 0),
              kind: pair.$1.index,
              health: 500,
              reinforced: heavy,
            )..health = 350;
            run.enemies.add(enemy);
            if (enemy.type == EnemyType.memoryLeak) {
              run.leakPatches.add(
                MemoryLeakPatch(enemy.position + Vector2(0, 90), enemy)
                  ..age = 2,
              );
            }
            if (enemy.type == EnemyType.timerEvent) {
              enemy.telegraphRemaining = 0.5;
              enemy.pulseGaps = [0, pi];
            }
          }
        }
        run.phase = RunPhase.paused;
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: GameWidget(
                game: RuntimeGame(run)..text = GameText(language),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        if (Platform.environment['RUNTIME_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('/tmp/runtime-high-load-$language.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
