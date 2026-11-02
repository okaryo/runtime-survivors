import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/ui/upgrade_card.dart';
import 'package:runtime_survivors/ui/selection_build.dart';

void main() {
  testWidgets(
    'hover and focus compare the existing build without acquiring upgrades',
    (tester) async {
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
      Finder card(Upgrade upgrade) => find.byWidgetPredicate(
        (w) => w is UpgradeCard && w.upgrade == upgrade,
      );
      AcquiredUpgrade acquired() =>
          tester.widget<AcquiredUpgrade>(find.byType(AcquiredUpgrade));
      expect(acquired().highlighted, isTrue);
      final hpLine = tester
          .widget<Text>(find.byKey(const Key('preview-memory-0')))
          .textSpan!
          .toPlainText();
      expect(hpLine, contains('35/100 → 70/125'));
      final gcCost = tester
          .widget<Text>(find.byKey(const Key('preview-garbageCollection-2')))
          .textSpan!
          .toPlainText();
      expect(gcCost, contains('0.70s → 0.78s'));
      final oopCost = tester
          .widget<Text>(find.byKey(const Key('preview-oop-2')))
          .textSpan!
          .toPlainText();
      expect(oopCost, contains('35/100 → 35/95'));

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(5, 5));
      await mouse.moveTo(tester.getCenter(card(Upgrade.memory)));
      await tester.pump();
      expect(
        acquired().highlighted,
        isFalse,
      ); // New ability: no existing row to highlight.
      expect(
        tester.widget<UpgradeCard>(card(Upgrade.memory)).inspected,
        isTrue,
      );
      expect(game.run.health, 35);
      expect(game.run.rank(Upgrade.memory), 0);
      expect(game.run.phase, RunPhase.choosing);
      await tester.tap(
        find.descendant(
          of: card(Upgrade.memory),
          matching: find.byIcon(Icons.info_outline),
        ),
      );
      await tester.pump();
      expect(game.run.phase, RunPhase.choosing);
      expect(game.run.rank(Upgrade.memory), 0);
      expect(game.run.health, 35);
      // Return to the first card, then test normal Tab/Shift+Tab comparison.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<UpgradeCard>(card(Upgrade.memory)).inspected,
        isTrue,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      await tester.pump();
      expect(acquired().highlighted, isTrue);
      expect(
        tester.widget<UpgradeCard>(card(Upgrade.garbageCollection)).inspected,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump();
      expect(acquired().highlighted, isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
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
