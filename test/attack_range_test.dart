import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

void main() {
  test('target ranges stay bounded while spatial expansion still improves attack areas', () {
    final base = BuildStats.snapshot({});
    final wide = BuildStats.snapshot({
      Upgrade.cache: 6,
      Upgrade.spatialIndex: 6,
      Upgrade.bandwidth: 6,
    });
    expect(base.attackRange, 300);
    expect(base.streamRange, 285);
    expect(wide.attackRange, 420);
    expect(wide.streamRange, 380);
    expect(wide.patternRange, 520);
    expect(wide.objectRange, closeTo(291.4, 0.001));
    expect(wide.chainRadius, closeTo(192.2, 0.001));
    expect(wide.gcRadius / base.gcRadius, closeTo(1.6, 0.001));
    expect(wide.slowRadius / base.slowRadius, closeTo(1.6, 0.001));
    expect(wide.projectileSpeed, greaterThan(base.projectileSpeed));
  });
  test('stream connections have their own shorter range rather than borrowing maximum base range', () {
    final run = RunState(random: Random(19))
      ..start()
      ..enemies.clear()
      ..spawnRadius = 10000;
    run.upgrades.addAll({
      Upgrade.cache: 6,
      Upgrade.spatialIndex: 6,
      Upgrade.asyncStream: 4,
    });
    final target = TaskEnemy(
      Vector2(400, 0),
      kind: EnemyType.rpc.index,
      health: 100000,
    );
    run.enemies.add(target);
    run.update(0.01);
    expect(run.instructions, isNotEmpty);
    expect(
      run.abilities.streams.every((stream) => stream.target == null),
      isTrue,
    );
    target.position.setValues(370, 0);
    run.update(0.01);
    expect(run.abilities.streams.first.target, same(target));
  });
  test('a fast piercing shot is clipped to its travel limit before swept collision', () {
    final run = RunState(random: Random(2))
      ..start()
      ..enemies.clear()
      ..spawnRadius = 10000;
    final near = TaskEnemy(
      Vector2(80, 0),
      kind: EnemyType.deadlock.index,
      health: 1000,
    );
    final far = TaskEnemy(
      Vector2(160, 0),
      kind: EnemyType.deadlock.index,
      health: 1000,
    );
    run.enemies.addAll([near, far]);
    final shot = LinearProjectile(
      Vector2.zero(),
      Vector2(1600, 0),
      damage: 42,
      hostile: false,
      remainingDistance: 100,
    );
    run.projectiles.add(shot);
    run.update(0.05);
    run.update(0.05);
    expect(shot.position.x, closeTo(100, 0.001));
    expect(near.health, lessThan(1000));
    expect(far.health, 1000);
    expect(run.projectiles, isNot(contains(shot)));
  });
  test('bandwidth improves piercing speed without extending the actual weapon range', () {
    final run = RunState(random: Random(2))
      ..start()
      ..enemies.clear()
      ..spawnRadius = 10000;
    run.upgrades.addAll({
      Upgrade.patternMatching: 4,
      Upgrade.bandwidth: 6,
      Upgrade.spatialIndex: 6,
    });
    final near = TaskEnemy(
      Vector2(150, 0),
      kind: EnemyType.deadlock.index,
      health: 1000,
    );
    final far = TaskEnemy(
      Vector2(600, 0),
      kind: EnemyType.deadlock.index,
      health: 1000,
    );
    run.enemies.addAll([near, far]);
    run.update(0.01);
    final shot = run.projectiles.singleWhere((shot) => !shot.hostile);
    for (var i = 0; i < 20; i++) {
      run.instructions.clear();
      run.update(0.05);
    }
    expect(shot.position.distanceTo(Vector2.zero()), closeTo(520, 0.001));
    expect(far.health, 1000);
  });
}
