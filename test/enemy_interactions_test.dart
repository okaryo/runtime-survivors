import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(9))
  ..start()
  ..enemies.clear();

void main() {
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
    expect(late, {0, 1, 4, 5, 11});
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
