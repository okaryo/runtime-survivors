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

void main() {
  for (final scenario in [
    (const Size(1280, 640), 'en', 1.0),
    (const Size(1280, 720), 'ja', 1.25),
    (const Size(1366, 768), 'en', 1.25),
    (const Size(1440, 800), 'ja', 1.0),
    (const Size(600, 720), 'en', 1.0),
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
      await tester.ensureVisible(find.text(text('start')));
      await tester.tap(find.text(text('start')));
      await tester.pump();
      final game = tester
          .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
          .game!;
      game.run.addExperience(game.run.nextLevelXp);
      game.run.choices = [
        Upgrade.oop,
        Upgrade.functional,
        Upgrade.garbageCollection,
      ];
      game.refresh();
      await tester.pump();
      final panel = find.byType(UpgradeChoices);
      expect(
        find.descendant(of: panel, matching: find.byType(Scrollable)),
        findsNothing,
      );
      expect(find.text(text('implement')).hitTestable(), findsNWidgets(3));
      for (final card in find.byType(UpgradeCard).evaluate()) {
        final rect = tester.getRect(find.byWidget(card.widget));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(scenario.$1.height));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(scenario.$1.width));
      }
      await tester.tap(find.byType(UpgradeCard).last);
      await tester.pump();
      expect(game.run.rank(Upgrade.garbageCollection), 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    });
  }
}
