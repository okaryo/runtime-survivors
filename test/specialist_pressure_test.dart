import 'dart:io';
import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

// Fixed workloads compare behavior, not player survival or a predicted win rate.
({double lifetime, bool acted}) encounter(
  EnemyType type, {
  required bool heavy,
  bool pursue = false,
}) {
  final run = RunState(random: Random(2))
    ..start()
    ..enemies.clear()
    ..spawnRadius = 10000;
  run.upgrades.addAll({
    Upgrade.asyncStream: 4,
    Upgrade.oop: 4,
    Upgrade.functional: 4,
    Upgrade.jitCompilation: 4,
    Upgrade.compiler: 6,
    Upgrade.spatialIndex: 6,
    Upgrade.cache: 6,
    Upgrade.memory: 6,
  });
  run.abilities.jitCharge = 60;
  final distance = switch (type) {
    EnemyType.rpc => heavy ? 490.0 : 450.0,
    EnemyType.timerEvent => heavy ? 350.0 : 310.0,
    EnemyType.memoryLeak => 460.0,
    _ => 420.0,
  };
  final target = TaskEnemy(
    Vector2(distance, 0),
    kind: type.index,
    health: SpawnDirector.healthFor(type, 240, reinforced: heavy),
    reinforced: heavy,
  );
  run.enemies.add(target);
  var acted = false;
  for (var i = 0; i < 1200 && target.alive; i++) {
    run.health = run.maxHealth;
    run.enemies.removeWhere(
      (enemy) => !identical(enemy, target) && !identical(enemy.owner, target),
    );
    if (pursue) {
      run.movement.setFrom((target.position - run.player).normalized());
    }
    run.update(1 / 60);
    acted |=
        run.projectiles.any((shot) => shot.hostile) ||
        run.timerPulses.isNotEmpty ||
        run.leakPatches.any((patch) => identical(patch.source, target)) ||
        run.enemies.any((enemy) => identical(enemy.owner, target));
  }
  expect(target.alive, isFalse, reason: '$type remained unprocessed');
  return (lifetime: run.elapsed, acted: acted);
}

void main() {
  for (final type in [
    EnemyType.rpc,
    EnemyType.timerEvent,
    EnemyType.memoryLeak,
    EnemyType.forkBomb,
  ]) {
    test(
      '$type gets an action opportunity under ambient fire and remains worth prioritizing',
      () {
        final normal = encounter(type, heavy: false);
        final heavy = encounter(type, heavy: true);
        final focused = encounter(type, heavy: true, pursue: true);
        if (Platform.environment['RUNTIME_BALANCE_REPORT'] == '1') {
          stdout.writeln(
            '$type: ordinary=${normal.lifetime.toStringAsFixed(2)}s acted=${normal.acted}; high-load=${heavy.lifetime.toStringAsFixed(2)}s acted=${heavy.acted}; pursued=${focused.lifetime.toStringAsFixed(2)}s',
          );
        }
        expect(normal.acted, isTrue);
        expect(heavy.acted, isTrue);
        expect(heavy.lifetime, greaterThan(normal.lifetime));
        expect(focused.lifetime, lessThan(heavy.lifetime));
      },
    );
  }
}
