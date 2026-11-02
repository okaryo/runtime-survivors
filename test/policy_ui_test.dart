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
import 'package:runtime_survivors/ui/choice_card_surface.dart';

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
          [Upgrade.compiler, Upgrade.nullSafety, Upgrade.memory],
          [Upgrade.nullSafety, Upgrade.patternMatching, Upgrade.compiler],
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
    for (final policy in TypingPolicy.values) {
      testWidgets(
        '$language $policy: bonus policy choice keeps HUD and queued upgrade, keyboard focus works',
        (tester) async {
          tester.view.physicalSize = const Size(1280, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final settings = GameSettings()..language = language;
          await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.sendKeyEvent(
            policy == TypingPolicy.staticTyping
                ? LogicalKeyboardKey.digit1
                : LogicalKeyboardKey.digit2,
          );
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          final game = tester
              .widget<GameWidget<RuntimeGame>>(
                find.byType(GameWidget<RuntimeGame>),
              )
              .game!;
          game.run.level = 4;
          game.run.health = 37;
          final hud = tester.getRect(find.byKey(const Key('memory-status')));
          game.run.addExperience(game.run.nextLevelXp);
          game.run.choices = [Upgrade.memory, Upgrade.oop, Upgrade.compiler];
          game.refresh();
          await tester.pump();
          await tester.pump();
          expect(
            find.byKey(const Key('policy-upgrade-choices')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.getRect(find.byKey(const Key('memory-status'))), hud);
          expect(find.byType(UpgradeCard), findsNothing);
          List<double> outlineWidths() => tester
              .widgetList<Material>(
                find.descendant(
                  of: find.byType(ChoiceCardSurface),
                  matching: find.byType(Material),
                ),
              )
              .map(
                (material) =>
                    (material.shape! as RoundedRectangleBorder).side.width,
              )
              .toList();
          expect(outlineWidths(), [1.2, 1.2]);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(game.run.policyChoicePending, isTrue);
          expect(outlineWidths(), [1.2, 1.2]);
          for (final upgrade in PolicyUpgrade.values) {
            final rect = tester.getRect(
              find.byKey(Key('policy-upgrade-${upgrade.name}')),
            );
            expect(rect.top, greaterThan(hud.bottom));
            expect(
              rect.bottom,
              lessThan(
                tester.getRect(find.byKey(const Key('experience-status'))).top,
              ),
            );
          }
          // First bonus choice by digit, then the queued regular choice by Tab/Enter.
          await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
          await tester.pump();
          await tester.pump();
          expect(game.run.policyPotency, 1);
          expect(game.run.health, 37);
          expect(find.byType(UpgradeCard).hitTestable(), findsNWidgets(3));
          expect(outlineWidths(), [1.2, 1.2, 1.2]);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlineWidths(), [2.5, 1.2, 1.2]);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(game.run.rank(Upgrade.oop), 1);
          expect(game.run.phase, RunPhase.running);
          // A later bonus uses Tab/Enter, and the following regular choice uses a digit.
          game.run.level = 9;
          game.run.addExperience(game.run.nextLevelXp);
          game.run.choices = [Upgrade.memory, Upgrade.oop, Upgrade.compiler];
          game.refresh();
          await tester.pump();
          await tester.pump();
          expect(outlineWidths(), [1.2, 1.2]);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlineWidths(), [2.5, 1.2]);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          expect(outlineWidths(), [1.2, 2.5]);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          await tester.pump();
          expect(game.run.policyPotency, 2);
          await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
          await tester.pump();
          expect(game.run.rank(Upgrade.memory), 1);
          expect(game.run.phase, RunPhase.running);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          settings.dispose();
        },
      );
    }
  }
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: keyboard chooses policy, results explain the build, restart offers a fresh policy',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = GameSettings()..language = language;
        await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
        await tester.pump();
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const Key('policy-dynamicTyping')))
              .selected,
          isTrue,
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        final game = tester
            .widget<GameWidget<RuntimeGame>>(
              find.byType(GameWidget<RuntimeGame>),
            )
            .game!;
        expect(game.run.typingPolicy, TypingPolicy.dynamicTyping);
        expect(game.run.phase, RunPhase.running);
        game.run.upgrades.addAll({
          Upgrade.garbageCollection: 1,
          Upgrade.oop: 3,
          Upgrade.functional: 1,
          Upgrade.patternMatching: 1,
          for (final upgrade in [
            Upgrade.memory,
            Upgrade.clock,
            Upgrade.cache,
            Upgrade.compiler,
          ])
            upgrade: 2,
        });
        tester.view.physicalSize = const Size(1280, 640);
        game.run.phase = RunPhase.lost;
        game.refresh();
        await tester.pump();
        expect(find.textContaining('Ruby').hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('language-profile')), findsOneWidget);
        expect(
          tester
              .renderObject(find.byKey(const Key('language-profile')))
              .getTransformTo(null)
              .getMaxScaleOnAxis(),
          greaterThanOrEqualTo(0.85),
        );
        await tester.tap(
          find.text(language == 'ja' ? '次の言語を設計' : 'Design another language'),
        );
        await tester.pump();
        expect(game.run.phase, RunPhase.ready);
        expect(game.run.health, 100);
        expect(game.run.upgrades, isEmpty);
        expect(game.run.typingPolicy, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(game.run.typingPolicy, TypingPolicy.staticTyping);
        expect(game.run.upgrades, isEmpty);
        expect(game.run.health, 100);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      },
    );
  }
}
