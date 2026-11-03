import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

// A stationary workload checks that every first Feature is useful on its own.
// Sixteen seconds includes JIT's warm-up and its subsequent payoff.
// This does not assert a survival rate or substitute for playing the game.
double processWork(Upgrade? feature) {
  final run = RunState(random: Random(21))
    ..start()
    ..spawnRadius =
        10000 // Keep incidental waves outside this fixed workload.
    ..enemies.clear();
  if (feature != null) run.upgrades[feature] = 1;
  final targets = [
    TaskEnemy(Vector2(55, 0), health: 100000),
    TaskEnemy(Vector2(95, 0), health: 100000),
    TaskEnemy(Vector2(135, 0), health: 100000),
  ];
  run.enemies.addAll(targets);
  for (var frame = 0; frame < 960; frame++) {
    for (var i = 0; i < targets.length; i++) {
      targets[i].position.setValues(55.0 + i * 40, 0);
    }
    run.health = run.maxHealth;
    run.update(1 / 60);
  }
  return targets.fold(
    0,
    (sum, target) => sum + target.maxHealth - target.health,
  );
}

void main() {
  for (final feature in Upgrade.values.where(
    (u) => u.isAvailable && u.isFeature,
  )) {
    test(
      'first $feature increases processing without requiring another Feature',
      () {
        expect(processWork(feature), greaterThan(processWork(null)));
      },
    );
  }
  test(
    'feature tradeoffs are explicit without removing targeting or movement',
    () {
      final baseline = BuildStats.snapshot({});
      for (final feature in Upgrade.values.where(
        (u) => u.isAvailable && u.isFeature,
      )) {
        final stats = BuildStats.snapshot({feature: 1});
        expect(stats.attackRange, baseline.attackRange);
        expect(stats.speed, baseline.speed);
      }
      final concurrency = BuildStats.snapshot({Upgrade.concurrency: 1});
      expect(concurrency.attackDamage, lessThan(baseline.attackDamage));
      expect(
        concurrency.attackDamage * concurrency.targetCount,
        greaterThan(baseline.attackDamage),
      );
      expect(BuildStats.snapshot({Upgrade.memoization: 1}).maxHealth, 92);
      expect(BuildStats.snapshot({Upgrade.oop: 1}).maxHealth, 94);
      final composed = BuildStats.snapshot({Upgrade.functional: 1});
      expect(composed.attackInterval, greaterThan(baseline.attackInterval));
      expect(composed.chainRetention, greaterThan(0.7));
      final reserved = BuildStats.snapshot({
        Upgrade.oop: 4,
        Upgrade.memoization: 4,
      });
      expect(reserved.maxHealth, 44);
    },
  );
}
