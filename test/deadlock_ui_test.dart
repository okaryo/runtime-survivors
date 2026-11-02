import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/ui/upgrade_card.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  for (final language in ['ja', 'en']) {
    for (final scale in [1.0, 1.25]) {
      testWidgets(
        '$language $scale: boss telemetry and tradeoff cards fit without covering memory',
        (tester) async {
          tester.view.physicalSize = scale == 1
              ? const Size(1280, 640)
              : const Size(1366, 768);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final settings = GameSettings()..language = language;
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            RepaintBoundary(
              key: boundaryKey,
              child: RuntimeSurvivorsApp(settings: settings),
            ),
          );
          await tester.pump(const Duration(milliseconds: 100));
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          final game = tester
              .widget<GameWidget<RuntimeGame>>(
                find.byType(GameWidget<RuntimeGame>),
              )
              .game!;
          game.run.elapsed = 74.99;
          game.run.update(0.02);
          game.run.deadlocks.single.warningRemaining = 0;
          game.refresh();
          await tester.pump();
          final memory = tester.getRect(find.byKey(const Key('memory-status')));
          final boss = tester.getRect(find.byKey(const Key('deadlock-status')));
          final timer = tester.getRect(find.byKey(const Key('remaining-time')));
          expect(memory.overlaps(boss), isFalse);
          expect(timer.overlaps(boss), isFalse);
          Future<void> capture(String path) async {
            if (Platform.environment['RUNTIME_CAPTURE'] != '1' ||
                language != 'ja' ||
                scale != 1) {
              return;
            }
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.png,
              ))!;
              await File(path).writeAsBytes(bytes.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('/tmp/runtime-survivors-deadlock.png');
          game.run.addExperience(game.run.nextLevelXp);
          game.run.choices = [
            Upgrade.garbageCollection,
            Upgrade.memoization,
            Upgrade.concurrency,
          ];
          game.refresh();
          await tester.pump();
          await tester.pump();
          expect(find.byType(UpgradeCard).hitTestable(), findsNWidgets(3));
          for (final card in find.byType(UpgradeCard).evaluate()) {
            final rect = tester.getRect(find.byWidget(card.widget));
            expect(rect.top, greaterThan(memory.bottom));
            expect(rect.overlaps(boss), isFalse);
            expect(
              rect.bottom,
              lessThan(
                tester.getRect(find.byKey(const Key('experience-status'))).top,
              ),
            );
          }
          expect(tester.takeException(), isNull);
          await capture('/tmp/runtime-survivors-feature-tradeoffs.png');
          await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
          await tester.pump();
          expect(game.run.maxHealth, 92);
          expect(game.run.health, lessThanOrEqualTo(92));
          await tester.pumpWidget(const SizedBox());
          settings.dispose();
        },
      );
    }
  }
}
