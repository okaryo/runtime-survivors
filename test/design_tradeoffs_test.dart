import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'run_state_test.dart' show grant, tick;

void main() {
  test(
    'collection briefly waits base attacks while movement and objects continue',
    () {
      final run = RunState()
        ..start()
        ..enemies.clear();
      grant(run, Upgrade.garbageCollection);
      run.upgrades[Upgrade.oop] = 1;
      run.enemies.add(TaskEnemy(Vector2(220, 0), health: 100000));
      tick(run, 0.61);
      expect(run.abilities.gcPause, greaterThan(0));
      run.instructions.clear();
      run.objects.single.attackTimer = 0;
      run.movement.setValues(0, 1);
      final position = run.player.clone();
      tick(run, 0.06);
      expect(
        run.instructions.where((s) => s.kind == InstructionKind.base),
        isEmpty,
      );
      expect(
        run.instructions.where((s) => s.kind == InstructionKind.object),
        isNotEmpty,
      );
      expect(run.player.distanceTo(position), greaterThan(0));
      run.pause();
      final wait = run.abilities.gcPause;
      tick(run, 2);
      expect(run.abilities.gcPause, wait);
      run.start();
      expect(run.abilities.gcPause, 0);
    },
  );
  test(
    'cache memory reservations are previewed, bounded and reset between runs',
    () {
      final run = RunState()..start();
      final preview = run.preview(Upgrade.memoization);
      expect(preview.after.maxHealth, 92);
      expect(preview.afterHealth, 92);
      expect(const GameText('ja').comparisons(preview).last.cost, isTrue);
      grant(run, Upgrade.memoization);
      expect(run.health, 92);
      run.health = 2;
      grant(run, Upgrade.memoization);
      expect(run.health, 2);
      expect(run.maxHealth, 84);
      run.start();
      expect(run.maxHealth, 100);
    },
  );
  test(
    'object and cache reservations stack, match previews and reset together',
    () {
      final run = RunState()..start();
      for (var rank = 0; rank < 4; rank++) {
        for (final feature in [Upgrade.oop, Upgrade.memoization]) {
          final preview = run.preview(feature);
          expect(const GameText('ja').comparisons(preview).last.cost, isTrue);
          grant(run, feature);
          expect(run.health, preview.afterHealth);
          expect(run.maxHealth, preview.after.maxHealth);
        }
      }
      expect(run.maxHealth, 44);
      expect(run.health, 44);
      grant(run, Upgrade.memory);
      expect(run.maxHealth, 69);
      expect(run.health, 69);
      run.start();
      expect(run.maxHealth, 100);
      expect(run.health, 100);
    },
  );
  test(
    'spatial expansion benefits base range and every geometric attack family',
    () {
      final before = BuildStats.snapshot({});
      final after = BuildStats.snapshot({Upgrade.spatialIndex: 1});
      for (final pair in [
        (before.attackRange, after.attackRange),
        (before.gcRadius, after.gcRadius),
        (before.slowRadius, after.slowRadius),
        (before.chainRadius, after.chainRadius),
        (before.objectRange, after.objectRange),
        (before.ownershipRadius, after.ownershipRadius),
        (before.patternRadius, after.patternRadius),
      ]) {
        expect(pair.$2, greaterThan(pair.$1));
      }
    },
  );
}
