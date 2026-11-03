import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

void main() {
  test('first concurrency preserves early one-hit requests and later ranks retain their tradeoff', () {
    final first = BuildStats.snapshot({Upgrade.concurrency: 1});
    expect(first.attackDamage, closeTo(23.04, 1e-6));
    expect(
      first.attackDamage,
      greaterThanOrEqualTo(SpawnDirector.healthFor(EnemyType.request, 18)),
    );
    expect(
      first.attackDamage,
      lessThan(SpawnDirector.healthFor(EnemyType.request, 20)),
    );
    final run = RunState(random: Random(12))
      ..start()
      ..enemies.clear()
      ..spawnRadius = 100000;
    run.upgrades[Upgrade.concurrency] = 1;
    final target = TaskEnemy(
      Vector2(100, 0),
      health: SpawnDirector.healthFor(EnemyType.request, 18),
    );
    run.enemies.add(target);
    for (var frame = 0; frame < 15; frame++) {
      run.update(1 / 60);
    }
    expect(target.alive, isFalse);
    var previous = first.attackDamage;
    for (var rank = 2; rank <= 4; rank++) {
      final stats = BuildStats.snapshot({Upgrade.concurrency: rank});
      expect(stats.attackDamage, lessThan(previous));
      expect(stats.targetCount, rank + 1);
      previous = stats.attackDamage;
    }
  });

  test('allocation gains a gentler late durability curve without changing its early role', () {
    expect(SpawnDirector.healthFor(EnemyType.allocation, 120), 86);
    expect(SpawnDirector.healthFor(EnemyType.allocation, 180), 144);
    expect(
      SpawnDirector.healthFor(EnemyType.allocation, 240),
      closeTo(254.4, 1e-6),
    );
    expect(
      SpawnDirector.healthFor(EnemyType.allocation, 270),
      closeTo(362.1375, 1e-6),
    );
    expect(
      SpawnDirector.healthFor(EnemyType.allocation, 270),
      lessThan(SpawnDirector.healthFor(EnemyType.rpc, 270)),
    );
    expect(SpawnDirector.healthFor(EnemyType.request, 180), 32);
  });

  test('ownership ranks cap healing below continuous low-damage hazards even with maximum protection', () {
    for (var rank = 1; rank <= 4; rank++) {
      final stats = BuildStats.snapshot({
        Upgrade.ownership: rank,
        Upgrade.memoryProtection: 6,
      });
      expect(stats.ownershipCap, rank + 2);
      expect(stats.ownershipHeal, rank + 1);
      expect(
        stats.ownershipCap,
        lessThan(MemoryLeakPatch.damage / stats.hitInvulnerability),
      );
    }
    final run = RunState(random: Random(12))
      ..start()
      ..enemies.clear()
      ..spawnRadius = 100000
      ..health = 60;
    run.upgrades.addAll({Upgrade.ownership: 4, Upgrade.memoryProtection: 6});
    final source = TaskEnemy(
      Vector2(500, 0),
      kind: EnemyType.memoryLeak.index,
      health: 100000,
    );
    run.enemies.add(source);
    run.leakPatches.add(MemoryLeakPatch(Vector2.zero(), source)..age = 1);
    for (var frame = 0; frame < 480; frame++) {
      run.xp = -1000000;
      run.experience.clear();
      if (frame % 12 == 0) {
        run.enemies.addAll(
          List.generate(3, (_) => TaskEnemy(Vector2(60, 0), health: 1)),
        );
      }
      run.update(1 / 60);
    }
    expect(run.phase, RunPhase.running);
    expect(run.health, lessThan(60));
  });
}
