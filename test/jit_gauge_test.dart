import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(91))
  ..start()
  ..spawnRadius = 10000
  ..enemies.clear()
  ..upgrades[Upgrade.jitCompilation] = 1;

void finish(
  RunState run, {
  bool summoned = false,
  EnemyType type = EnemyType.request,
}) {
  final target = TaskEnemy(
    Vector2(200, 0),
    health: 1,
    summoned: summoned,
    kind: type.index,
  );
  run.enemies.add(target);
  run.instructions.add(Instruction(target.position.clone(), target, 1));
  run.update(0.01);
}

void main() {
  test('tougher workloads reward more optimization than requests, batches and copies', () {
    final gains = <EnemyType, double>{};
    for (final type in EnemyType.values.where(
      (type) => type.isDiscoverable || type == EnemyType.lockNode,
    )) {
      final run = prepared();
      finish(run, type: type);
      gains[type] = run.jitCharge;
    }
    expect(gains[EnemyType.batch], lessThan(gains[EnemyType.request]!));
    expect(gains[EnemyType.request], inInclusiveRange(2, 4));
    expect(gains[EnemyType.interrupt], greaterThan(gains[EnemyType.request]!));
    for (final type in [
      EnemyType.allocation,
      EnemyType.rpc,
      EnemyType.timerEvent,
      EnemyType.memoryLeak,
      EnemyType.forkBomb,
    ]) {
      expect(gains[type], greaterThan(gains[EnemyType.interrupt]!));
    }
    expect(gains[EnemyType.deadlock], greaterThan(gains[EnemyType.forkBomb]!));
    final copies = prepared();
    finish(copies, summoned: true, type: EnemyType.forkBomb);
    expect(copies.jitCharge, lessThan(gains[EnemyType.batch]!));
  });
  test('kills build a bounded gauge; firing at unfinished tasks cannot maintain it', () {
    final run = prepared();
    finish(run);
    expect(run.jitCharge, 3);
    expect(run.attackInterval, lessThan(0.62));
    run.enemies.add(TaskEnemy(Vector2(260, 0), health: 100000));
    tick(run, 0.2);
    expect(run.jitCharge, closeTo(1.2, 0.001));
    tick(run, 0.2);
    expect(run.jitCharge, 0);
    expect(run.attackInterval, 0.62);
    for (var i = 0; i < 40; i++) {
      finish(run);
    }
    expect(run.jitCharge, 100);
    final preview = run.preview(Upgrade.jitCompilation);
    expect(preview.before.attackInterval, run.attackInterval);
    expect(preview.after.attackInterval, lessThan(run.attackInterval));
    expect(
      run.preview(Upgrade.compiler).after.attackInterval,
      closeTo(run.attackInterval * 0.92, 0.001),
    );
  });

  test('copies grant less charge; pause and selection freeze decay; restart clears it', () {
    final run = prepared();
    finish(run, summoned: true);
    expect(run.jitCharge, 0.5);
    run.pause();
    tick(run, 3);
    expect(run.jitCharge, 0.5);
    run.resume();
    run.addExperience(run.nextLevelXp);
    tick(run, 3);
    expect(run.jitCharge, 0.5);
    run.start();
    expect(run.jitCharge, 0);
    expect(run.attackInterval, 0.62);
  });

  test('weak tasks cannot sustain a high gauge alone while tougher workloads charge it faster', () {
    (int, double) process(bool jit, {EnemyType type = EnemyType.request}) {
      final run = prepared();
      if (!jit) run.upgrades.clear();
      var peak = 0.0;
      final workload = <TaskEnemy>{};
      for (var i = 0; i < 1200; i++) {
        // Keep incidental waves out of this comparison, even when targets are
        // repositioned near the player to maintain a stationary workload.
        run.enemies.removeWhere((enemy) => !workload.contains(enemy));
        if (run.enemies.length < 15) {
          final target = TaskEnemy(
            Vector2(150, 0),
            health: 22,
            kind: type.index,
          );
          workload.add(target);
          run.enemies.add(target);
        }
        run.experience.clear();
        for (final target in run.enemies) {
          target.position.setValues(180, 0);
        }
        run.health = run.maxHealth;
        run.update(1 / 60);
        peak = max(peak, run.jitCharge);
      }
      return (run.kills, peak);
    }

    final boosted = process(true), baseline = process(false);
    expect(boosted.$1, greaterThanOrEqualTo(baseline.$1));
    expect(boosted.$2, greaterThan(0));
    expect(boosted.$2, lessThanOrEqualTo(4));
    final tougher = process(true, type: EnemyType.allocation);
    expect(tougher.$2, greaterThan(boosted.$2));
    expect(tougher.$1, greaterThan(baseline.$1));
  });
}
