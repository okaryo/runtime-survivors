import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';

import 'support/runtime_fonts.dart';

import 'package:runtime_survivors/ui/upgrade_card.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: new cards fit a PC viewport without internal scrolling',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = GameSettings()..language = language;
        await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final game = tester
            .widget<GameWidget<RuntimeGame>>(
              find.byType(GameWidget<RuntimeGame>),
            )
            .game!;
        game.run.addExperience(game.run.nextLevelXp);
        for (final choices in [
          [Upgrade.oop, Upgrade.functional, Upgrade.garbageCollection],
          [Upgrade.concurrency, Upgrade.memory, Upgrade.cache],
          [Upgrade.compiler, Upgrade.memoization, Upgrade.memory],
          [Upgrade.memoization, Upgrade.patternMatching, Upgrade.compiler],
          [Upgrade.lazyEvaluation, Upgrade.memoization, Upgrade.jitCompilation],
          [Upgrade.ownership, Upgrade.spatialIndex, Upgrade.coprocessor],
          [Upgrade.memoryProtection, Upgrade.bandwidth, Upgrade.clock],
        ]) {
          game.run.choices = choices;
          game.refresh();
          await tester.pump();
          await tester.pump();
          expect(find.byType(UpgradeCard).hitTestable(), findsNWidgets(3));
          for (final card in find.byType(UpgradeCard).evaluate()) {
            expect(
              tester.getRect(find.byWidget(card.widget)).bottom,
              lessThanOrEqualTo(640),
            );
          }
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      },
    );
  }
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: start is immediate and milestones keep the ordinary choices',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = GameSettings()..language = language;
        await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(ChoiceChip), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final game = tester
            .widget<GameWidget<RuntimeGame>>(
              find.byType(GameWidget<RuntimeGame>),
            )
            .game!;
        expect(game.run.phase, RunPhase.running);
        for (final level in [5, 10, 15]) {
          game.run.level = level - 1;
          game.run.addExperience(game.run.nextLevelXp);
          game.run.choices = [Upgrade.memory, Upgrade.oop, Upgrade.compiler];
          game.refresh();
          await tester.pump();
          await tester.pump();
          expect(find.byType(UpgradeCard), findsNWidgets(3));
          await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
          await tester.pump();
          expect(game.run.phase, RunPhase.running);
        }
        game.run.upgrades.clear();
        game.run.upgrades.addAll({
          Upgrade.garbageCollection: 1,
          Upgrade.oop: 3,
        });
        game.run.phase = RunPhase.won;
        game.refresh();
        await tester.pump();
        expect(find.textContaining('Java').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      },
    );
  }
}
