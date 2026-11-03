import 'dart:io';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/main.dart';
import 'package:runtime_survivors/settings.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/runtime_game.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'support/runtime_fonts.dart';

void main() {
  setUpAll(loadRuntimeFonts);
  for (final language in ['ja', 'en']) {
    testWidgets(
      '$language: exception cards, ready status and counter feedback render with legacy discoveries',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final settings = GameSettings()
          ..language = language
          ..discoveries.add('upgrade.memoization');
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
        final run = game.run;
        final text = GameText(language);
        run.upgrades[Upgrade.garbageCollection] = 1;
        run.upgrades[Upgrade.jitCompilation] = 1;
        run.addExperience(run.nextLevelXp);
        run.choices = [
          Upgrade.exceptionHandling,
          Upgrade.compiler,
          Upgrade.ownership,
        ];
        game.refresh();
        await tester.runAsync(() async {
          for (final upgrade in [
            Upgrade.exceptionHandling,
            Upgrade.compiler,
            Upgrade.ownership,
            Upgrade.garbageCollection,
            Upgrade.jitCompilation,
          ]) {
            await precacheImage(
              AssetImage('assets/icons/upgrades/${upgrade.name}.png'),
              boundaryKey.currentContext!,
            );
          }
        });
        await tester.pump();
        await tester.pump();
        expect(find.text(text.title(Upgrade.memoization)), findsNothing);
        expect(settings.discoveries, contains('upgrade.memoization'));
        expect(
          settings.discoveries,
          isNot(contains('upgrade.exceptionHandling')),
        );
        expect(
          find.byKey(const Key('change-exceptionHandling-3')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        if (Platform.environment['RUNTIME_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('/tmp/runtime-exception-card-$language.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
        await tester.pump();
        expect(run.rank(Upgrade.exceptionHandling), 1);
        expect(find.text(text('exceptionReady')), findsOneWidget);
        expect(settings.discoveries, contains('upgrade.exceptionHandling'));
        run.enemies.clear();
        run.projectiles.add(
          LinearProjectile(run.player.clone(), Vector2.zero(), damage: 20),
        );
        run.update(0.01);
        game.refresh();
        await tester.pump();
        expect(run.health, 88);
        expect(find.text(text('exceptionReady')), findsNothing);
        expect(find.byKey(const Key('exception-status')), findsOneWidget);
        expect(run.effects.any((e) => e.counter), isTrue);
        expect(tester.takeException(), isNull);
        if (Platform.environment['RUNTIME_CAPTURE'] == '1') {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.png,
            ))!;
            await File('/tmp/runtime-exception-counter-$language.png')
                .writeAsBytes(bytes.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        settings.dispose();
      },
    );
  }
}
