import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/ability_runtime.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(9))
  ..start()
  ..enemies.clear();

void main() {
  for (final type in [
    EnemyType.rpc,
    EnemyType.forkBomb,
    EnemyType.memoryLeak,
    EnemyType.timerEvent,
  ]) {
    test('$type approaches, holds a band and retreats when pursued', () {
      final run = prepared()..spawnRadius = 10000;
      final enemy = TaskEnemy(Vector2(500, 0), kind: type.index, health: 100000)
        ..attackCooldown = 1000;
      run.enemies.add(enemy);
      run.update(0.05);
      expect(enemy.position.x, lessThan(500));

      final range = enemy.preferredRange!;
      final middle = (range.near + range.far) / 2;
      enemy.position.setValues(middle, 0);
      tick(run, 0.2);
      expect(enemy.position.distanceTo(run.player), closeTo(middle, 0.001));
      if (type != EnemyType.memoryLeak) {
        expect(enemy.position.x, closeTo(middle, 0.001));
      }
      enemy.position.setValues(80, 0);
      run.update(0.05);
      expect(enemy.position.x, greaterThan(80));
      expect(
        enemy.speed,
        lessThan(run.speed),
      ); // It remains possible to pursue.

      enemy.position.setFrom(run.player);
      run.update(0.05);
      expect(enemy.position.distanceTo(run.player), greaterThan(0));
      final position = enemy.position.clone();
      run.pause();
      tick(run, 0.5);
      expect(enemy.position, position);
    });
  }
  test(
    'fork copies still close all the way to contact instead of retreating',
    () {
      final run = prepared()..spawnRadius = 10000;
      final root = TaskEnemy(Vector2(300, 0), kind: EnemyType.forkBomb.index);
      final copy = TaskEnemy(
        Vector2(60, 0),
        kind: EnemyType.forkBomb.index,
        health: 100000,
        owner: root,
        summoned: true,
        generation: 2,
      )..attackCooldown = 1000;
      run.enemies.add(copy);
      expect(copy.preferredRange, isNull);
      tick(run, 0.7);
      expect(copy.position.distanceTo(run.player), lessThan(copy.radius + 13));
      expect(run.health, lessThan(100));
    },
  );
  test(
    'retreat respects lingering evaluation slow and casting remains stationary',
    () {
      final run = prepared()..spawnRadius = 10000;
      run.upgrades[Upgrade.lazyEvaluation] = 1;
      final rpc = TaskEnemy(
        Vector2(80, 0),
        kind: EnemyType.rpc.index,
        health: 100000,
      )..attackCooldown = 1000;
      run.enemies.add(rpc);
      // The active field covers both the enemy and its next movement step.
      run.abilities.fields.add(
        SlowField(Vector2(80, 0), 100, 0.7)..triggered = true,
      );
      run.update(0.05);
      expect(rpc.position.x - 80, closeTo(rpc.speed * 0.7 * 0.05, 0.001));
      rpc.telegraphRemaining = 0.5;
      final position = rpc.position.clone();
      run.update(0.05);
      expect(rpc.position, position);
    },
  );
  test(
    'RPC maintains a firing distance beyond base range but can be pursued',
    () {
      final run = prepared()..spawnRadius = 10000;
      final rpc = TaskEnemy(
        Vector2(340, 0),
        kind: EnemyType.rpc.index,
        health: 1000,
      );
      run.enemies.add(rpc);
      tick(run, 2.2);
      expect(rpc.position.distanceTo(run.player), greaterThan(run.attackRange));
      expect(rpc.health, 1000);
      expect(run.projectiles.where((shot) => shot.hostile), isNotEmpty);
      run.movement.setValues(1, 0);
      tick(run, 1);
      expect(rpc.health, lessThan(1000));
    },
  );
  test('spawned ranged tasks withstand multiple base shots', () {
    final run = prepared()..elapsed = 65;
    tick(run, 2.5);
    final rpc = run.enemies.firstWhere((e) => e.type == EnemyType.rpc);
    final timer = run.enemies.firstWhere((e) => e.type == EnemyType.timerEvent);
    expect(rpc.maxHealth, greaterThan(run.attackDamage * 3));
    expect(timer.maxHealth, greaterThan(run.attackDamage * 3));
  });
  test('director offers distinct active tasks, honors batch limits and reserves first encounters', () {
    const director = SpawnDirector();
    final random = Random(6);
    expect(List.generate(100, (_) => director.choose(10, [], random)).toSet(), {
      0,
    });
    final late = List.generate(
      500,
      (_) => director.choose(220, [], random),
    ).toSet();
    expect(late, {0, 1, 2, 4, 5, 11, 13, 14});
    expect(
      SpawnDirector.rules.fold(
        0,
        (sum, rule) => sum + rule.cost * rule.batchSize,
      ),
      lessThanOrEqualTo(18),
    );
    for (final rule in SpawnDirector.rules) {
      final capped = [
        for (var i = 0; i < rule.limit; i++)
          TaskEnemy(Vector2.zero(), kind: rule.type.index),
      ];
      expect(
        List.generate(100, (_) => director.choose(220, capped, random)),
        isNot(contains(rule.type.index)),
      );
    }
    final occupied = [
      for (var i = 0; i < 3; i++) TaskEnemy(Vector2.zero(), kind: 4),
      for (var i = 0; i < 2; i++) TaskEnemy(Vector2.zero(), kind: 5),
    ];
    expect(
      List.generate(100, (_) => director.choose(220, occupied, random)),
      isNot(contains(11)),
    );
  });
  test('batch tasks move in a column and keep pursuing after the leader is processed', () {
    final run = prepared()..elapsed = 30;
    run.update(0.01);
    final batch = run.enemies.where((e) => e.type == EnemyType.batch).toList();
    expect(batch.length, 4);
    final leader = batch.first;
    for (var i = 1; i < batch.length; i++) {
      expect(
        batch[i].position.distanceTo(leader.position),
        closeTo(32.0 * i, 0.001),
      );
      expect(batch[i].owner, same(leader));
      expect(batch[i].cacheable, isTrue);
    }
    leader.health = 0;
    final follower = batch[1];
    final distance = follower.position.distanceTo(run.player);
    tick(run, 0.2);
    expect(follower.position.distanceTo(run.player), lessThan(distance));
    expect(
      run.enemies.any((e) => e.type == EnemyType.duplicateRequest),
      isFalse,
    );
  });
  test(
    'allocation returns after forty seconds as slow, durable, rewarding work',
    () {
      const director = SpawnDirector();
      final random = Random(10);
      expect(
        List.generate(100, (_) => director.choose(39.99, [], random)),
        isNot(contains(EnemyType.allocation.index)),
      );
      final run = prepared()..elapsed = 40;
      run.update(0.01); // The earlier batch introduction is still pending.
      tick(run, 0.7);
      final allocation = run.enemies.singleWhere(
        (enemy) => enemy.type == EnemyType.allocation,
      );
      expect(allocation.maxHealth, closeTo((22 + 40.66 / 18) * 3, 0.02));
      expect(allocation.speed, lessThan(TaskEnemy(Vector2.zero()).speed));
      expect(allocation.radius, greaterThan(TaskEnemy(Vector2.zero()).radius));
      expect(run.seenEnemies, contains(2));
      expect(allocation.type.isDiscoverable, isTrue);
      expect(allocation.cacheable, isFalse); // Allocation has side effects.
      run.enemies.removeWhere((enemy) => !identical(enemy, allocation));
      allocation.position.setFrom(run.player);
      run.update(0.01);
      expect(run.health, 85);
      // A normal shot can finish it; no Feature acts as a required counter.
      allocation.position.setValues(200, 0);
      allocation.health = 1;
      run.instructions.add(
        Instruction(allocation.position.clone(), allocation, 1),
      );
      run.update(0.01);
      expect(allocation.alive, isFalse);
      expect(run.experience.single.value, 9);
    },
  );
  test('RPC sends, waits, then retries with a capped fan and never homes', () {
    final run = prepared();
    final rpc = TaskEnemy(Vector2(240, 0), kind: 4, health: 100000)
      ..attackCooldown = 0;
    run.enemies.add(rpc);
    run.update(0.01);
    final direction = rpc.chargeDirection.clone();
    run.player.y = 50;
    tick(run, 0.66);
    expect(run.projectiles.where((s) => s.hostile).length, 1);
    expect(
      run.projectiles.first.velocity.normalized().distanceTo(direction),
      lessThan(0.0001),
    );
    for (final expected in [2, 3, 3]) {
      run.projectiles.clear();
      rpc.attackCooldown = 0;
      tick(run, 0.7);
      expect(run.projectiles.where((s) => s.hostile).length, expected);
      expect(rpc.attackCooldown, greaterThan(0));
    }
    run.pause();
    final cooldown = rpc.attackCooldown;
    tick(run, 3);
    expect(rpc.attackCooldown, cooldown);
  });
  test('fork copies grow in generations, stay bounded and stop copying when the parent dies', () {
    final run = prepared();
    final parent = TaskEnemy(Vector2(220, 0), kind: 5, health: 100000)
      ..attackCooldown = 0;
    run.enemies.add(parent);
    tick(run, 1.15);
    final first = run.enemies.where((e) => e.summoned).toList();
    expect(first.length, 2);
    expect(
      first.every((e) => e.type == EnemyType.forkBomb && e.generation == 1),
      isTrue,
    );
    parent.attackCooldown = 100;
    for (final child in first) {
      child.health = 100000;
      child.attackCooldown = 0;
    }
    tick(run, 1.2);
    expect(run.enemies.any((e) => e.generation == 2), isTrue);
    expect(run.enemies.where((e) => e.summoned).length, lessThanOrEqualTo(6));
    parent.health = 0;
    final count = run.enemies.where((e) => e.summoned).length;
    tick(run, 1.2);
    expect(
      run.enemies.where((e) => e.summoned).length,
      lessThanOrEqualTo(count),
    );
  });
}
