import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/l10n/game_text.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/ui/upgrade_card.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  testWidgets(
    'language switch preserves run; encyclopedia is always visible without blocking keys',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = GameSettings();
      await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.text('未実装'),
        findsNWidgets(RunState.featureSlots + RunState.infraSlots),
      );
      expect(find.byKey(const Key('encyclopedia-heading')), findsOneWidget);
      expect(
        tester.getRect(find.byKey(const Key('empty-infra-3'))).bottom,
        lessThanOrEqualTo(640),
      );
      await tester.tap(find.text('ランタイムを起動'));
      await tester.pump();
      final game = tester
          .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
          .game!;
      game.run.kills = 7;
      await tester.tap(find.byKey(const Key('language-toggle')));
      await tester.pump();
      expect(find.text('Running'), findsOneWidget);
      expect(game.run.kills, 7);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyH);
      await tester.pump();
      expect(game.run.movement.x, -1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyH);
      game.run.addExperience(game.run.nextLevelXp);
      game.refresh();
      await tester.pump();
      expect(find.byType(UpgradeCard), findsNWidgets(3));
      expect(find.text('FEATURE'), findsWidgets);
      expect(find.text('INFRA'), findsWidgets);
      final selected = tester
          .widget<UpgradeCard>(find.byType(UpgradeCard).first)
          .upgrade;
      await tester.ensureVisible(find.byType(UpgradeCard).first);
      await tester.tap(find.byType(UpgradeCard).first);
      await tester.pump();
      expect(game.run.phase, RunPhase.running);
      expect(settings.discoveries, contains('upgrade.${selected.name}'));
      expect(find.byKey(const Key('empty-feature-3')), findsOneWidget);
      expect(
        find.text('Unimplemented'),
        findsNWidgets(
          RunState.featureSlots +
              RunState.infraSlots -
              game.run.featureCount -
              game.run.infraCount,
        ),
      );
      expect(find.byKey(const Key('empty-infra-3')), findsOneWidget);
      expect(find.byKey(const Key('encyclopedia-toggle')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('encyclopedia-heading')));
      await tester.pump();
      expect(game.run.phase, RunPhase.running);
      expect(game.inputBlocked, isFalse);
      expect(find.text(const GameText('en')('enemy.0.title')), findsOneWidget);
      expect(find.text(const GameText('en')('enemy.3.title')), findsNothing);
      expect(find.text('???'), findsWidgets);
      expect(
        find.text(const GameText('en')('enemy.0.matchup')),
        findsOneWidget,
      );
      expect(find.text(const GameText('en')('enemy.3.matchup')), findsNothing);
      expect(find.text(const GameText('en').matchup(selected)), findsOneWidget);
      expect(find.textContaining('Tradeoff:'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(game.run.phase, RunPhase.paused);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyP);
      await tester.pump();
      expect(game.run.phase, RunPhase.running);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      settings.dispose();
    },
  );

  testWidgets('English upgrade cards remain usable in a smaller PC window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final settings = GameSettings()..language = 'en';
    await tester.pumpWidget(RuntimeSurvivorsApp(settings: settings));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start runtime'));
    await tester.pump();
    final game = tester
        .widget<GameWidget<RuntimeGame>>(find.byType(GameWidget<RuntimeGame>))
        .game!;
    game.run.addExperience(game.run.nextLevelXp);
    game.run.choices = [Upgrade.oop, Upgrade.functional, Upgrade.memory];
    game.refresh();
    await tester.pump();
    expect(find.byType(UpgradeCard), findsNWidgets(3));
    await tester.ensureVisible(find.byType(UpgradeCard).first);
    await tester.tap(find.byType(UpgradeCard).first);
    await tester.pump();
    expect(game.run.rank(Upgrade.oop), 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    settings.dispose();
  });
}
