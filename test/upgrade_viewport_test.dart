import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/l10n/game_text.dart';
import 'package:runtime_survivors/ui/upgrade_card.dart';
import 'package:runtime_survivors/ui/upgrade_choices.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  for (final scenario in [
    (const Size(1280, 640), 'en', 1.0),
    (const Size(1280, 720), 'ja', 1.25),
    (const Size(1366, 768), 'en', 1.25),
    (const Size(1440, 800), 'ja', 1.0),
    (const Size(1280, 800), 'en', 1.0),
    (const Size(1440, 900), 'en', 1.0),
  ]) {
    testWidgets('all choices fit without scrolling: $scenario', (tester) async {
      tester.view.physicalSize = scenario.$1;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scenario.$3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final settings = GameSettings()..language = scenario.$2;
      final text = GameText(settings.language);
      await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
      await tester.pump(const Duration(milliseconds: 100));
      if (scenario.$1.width >= 1180) {
        final arena = tester.getRect(find.byType(GameWidget<RuntimeGame>));
        expect(arena.bottom, lessThanOrEqualTo(scenario.$1.height));
      }
      await tester.tap(find.text(text('start')));
      await tester.pump();
      final game = tester
          .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
          .game!;
      final features = scenario.$2 == 'en'
          ? [
              Upgrade.garbageCollection,
              Upgrade.jitCompilation,
              Upgrade.memoization,
              Upgrade.nullSafety,
            ]
          : [
              Upgrade.oop,
              Upgrade.functional,
              Upgrade.garbageCollection,
              Upgrade.concurrency,
            ];
      final infra = [
        Upgrade.memory,
        Upgrade.cache,
        Upgrade.pipeline,
        Upgrade.bandwidth,
      ];
      game.run.upgrades.addAll({
        for (final upgrade in features) upgrade: 3,
        for (final upgrade in infra) upgrade: 2,
      });
      game.run.health = 35;
      game.refresh();
      await tester.pump();
      final arenaBefore = tester.getRect(find.byType(GameWidget<RuntimeGame>));
      final memoryBefore = tester.getRect(
        find.byKey(const Key('memory-status')),
      );
      final sidebarBefore = tester.getRect(
        find.byKey(const Key('design-panel')),
      );
      final acquiredBefore = {
        for (final upgrade in game.run.upgrades.keys)
          upgrade: tester.getRect(find.byKey(Key('acquired-${upgrade.name}'))),
      };
      game.run.addExperience(game.run.nextLevelXp);
      game.run.choices = [
        ...features.where((u) => u != Upgrade.garbageCollection).take(2),
        Upgrade.garbageCollection,
      ];
      game.refresh();
      await tester.pump();
      final panel = find.byType(UpgradeChoices);
      expect(
        find.descendant(of: panel, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(find.byType(UpgradeCard).hitTestable(), findsNWidgets(3));
      final arenaRect = tester.getRect(find.byType(GameWidget<RuntimeGame>));
      final panelRect = tester.getRect(panel);
      expect(panelRect, arenaRect);
      expect(arenaRect, arenaBefore);
      final hpRect = tester.getRect(find.byKey(const Key('memory-status')));
      expect(hpRect.top, greaterThanOrEqualTo(0));
      expect(hpRect.bottom, lessThanOrEqualTo(scenario.$1.height));
      expect(hpRect, memoryBefore);
      final hudRect = tester.getRect(find.byKey(const Key('runtime-hud')));
      expect(hudRect.contains(hpRect.center), isTrue);
      expect(hudRect.bottom, lessThanOrEqualTo(arenaRect.top));
      expect(arenaRect.height, greaterThan(scenario.$1.height - 290));
      expect(hpRect.bottom, lessThan(panelRect.top));
      final sidebarAfter = tester.getRect(
        find.byKey(const Key('design-panel')),
      );
      expect(sidebarAfter.topLeft, sidebarBefore.topLeft);
      expect(sidebarAfter.width, sidebarBefore.width);
      for (final upgrade in game.run.upgrades.keys) {
        expect(
          tester.getRect(find.byKey(Key('acquired-${upgrade.name}'))).bottom,
          lessThanOrEqualTo(scenario.$1.height),
        );
        expect(
          tester.getRect(find.byKey(Key('acquired-${upgrade.name}'))),
          acquiredBefore[upgrade],
        );
      }
      expect(
        find.descendant(of: panel, matching: find.byType(FittedBox)),
        findsNothing,
      );
      for (final upgrade in game.run.choices) {
        final description = find.text(text.description(upgrade));
        expect(description.hitTestable(), findsOneWidget);
        expect(
          tester.widget<Text>(description).style!.fontSize,
          greaterThanOrEqualTo(15),
        );
      }
      for (final card in find.byType(UpgradeCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(scenario.$1.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(scenario.$1.width));
      }
      await tester.tap(find.byType(UpgradeCard).last);
      await tester.pump();
      expect(game.run.rank(Upgrade.garbageCollection), 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    });
  }
}
