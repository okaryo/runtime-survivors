import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
  testWidgets(
    'all card details stay visible; keyboard selects without inspection',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = GameSettings();
      const text = GameText('ja');
      await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('ランタイムを起動'));
      await tester.pump();
      final game = tester
          .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
          .game!;
      game.run.upgrades[Upgrade.garbageCollection] = 1;
      game.run.health = 35;
      game.run.addExperience(game.run.nextLevelXp);
      game.run.choices = [
        Upgrade.garbageCollection,
        Upgrade.memory,
        Upgrade.oop,
      ];
      game.refresh();
      await tester.pump();
      final panel = find.byType(UpgradeChoices);
      expect(
        find.descendant(of: panel, matching: find.byType(Tooltip)),
        findsNothing,
      );
      for (final upgrade in game.run.choices) {
        expect(
          find.text(text.description(upgrade)).hitTestable(),
          findsOneWidget,
        );
      }
      String change(String key) =>
          tester.widget<Text>(find.byKey(Key(key))).textSpan!.toPlainText();
      expect(change('change-memory-0'), 'メモリ 35/100 → 70/125');
      expect(change('change-garbageCollection-2'), contains('0.70s → 0.78s'));
      expect(change('change-oop-2'), 'メモリ 35/100 → 35/95');
      final build = find.byKey(const Key('design-panel'));
      final buildBefore = tester
          .widgetList<Text>(
            find.descendant(of: build, matching: find.byType(Text)),
          )
          .map((w) => w.data)
          .toList();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 5));
      await mouse.moveTo(tester.getCenter(find.byType(UpgradeCard).at(1)));
      await tester.pump();
      expect(
        tester
            .widgetList<Text>(
              find.descendant(of: build, matching: find.byType(Text)),
            )
            .map((w) => w.data)
            .toList(),
        buildBefore,
      );
      expect(game.run.health, 35);
      expect(game.run.phase, RunPhase.choosing);
      // Focus starts on the first card. Tab + Enter acquires the second card.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(game.run.phase, RunPhase.running);
      expect(game.run.health, 70);
      expect(game.run.maxHealth, 125);
      expect(game.run.rank(Upgrade.memory), 1);
      expect(tester.takeException(), isNull);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );
  testWidgets('numeric shortcuts survive consecutive level-up screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = GameSettings();
    await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('ランタイムを起動'));
    await tester.pump();
    final game = tester
        .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
        .game!;
    for (var level = 0; level < 3; level++) {
      game.run.addExperience(game.run.nextLevelXp);
      game.run.choices = [
        Upgrade.garbageCollection,
        Upgrade.memory,
        Upgrade.oop,
      ];
      game.refresh();
      await tester.pump();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.pump();
      await tester.pump();
      expect(game.run.phase, RunPhase.running);
      expect(game.run.rank(Upgrade.memory), level + 1);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
