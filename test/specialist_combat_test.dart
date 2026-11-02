import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(4))
  ..start()
  ..enemies.clear();
void main() {
  test(
    'RPC locks aim during its telegraph and emits a non-homing projectile',
    () {
      final run = prepared();
      final rpc = TaskEnemy(Vector2(200, 0), kind: 4, health: 9999)
        ..attackCooldown = 0;
      run.enemies.add(rpc);
      run.update(0.01);
      final aim = rpc.chargeDirection.clone();
      run.player.y = 100;
      tick(run, 0.7);
      expect(run.projectiles, isNotEmpty);
      expect(
        run.projectiles.first.velocity.normalized().distanceTo(aim),
        lessThan(0.0001),
      );
      expect(rpc.attackCooldown, greaterThan(0));
    },
  );
  test('swept enemy projectile hits once and pause freezes it', () {
    final run = prepared();
    final shot = LinearProjectile(
      Vector2(-30, 0),
      Vector2(1200, 0),
      damage: 11,
    );
    run.projectiles.add(shot);
    run.pause();
    tick(run, 2);
    expect(shot.position.x, -30);
    run.resume();
    run.update(0.05);
    expect(run.health, 89);
    expect(run.projectiles, isEmpty);
    run.start();
    expect(run.projectiles, isEmpty);
  });
  test(
    'summoner queues children safely, respects per-parent and global caps',
    () {
      final run = prepared();
      final parent = TaskEnemy(Vector2(200, 0), kind: 5, health: 99999)
        ..attackCooldown = 0;
      run.enemies.add(parent);
      tick(run, 1.3);
      expect(run.enemies.where((e) => e.owner == parent).length, 2);
      for (var cycle = 0; cycle < 3; cycle++) {
        parent.attackCooldown = 0;
        tick(run, 1.3);
      }
      expect(
        run.enemies.where((e) => e.alive && e.owner == parent).length,
        lessThanOrEqualTo(6),
      );
      expect(run.enemies.length, lessThanOrEqualTo(240));
    },
  );
  test('director introduces specialists gradually and limits their budget', () {
    const director = SpawnDirector();
    final random = Random(7);
    expect(
      List.generate(
        100,
        (_) => director.choose(10, [], random),
      ).every((k) => k == 0),
      isTrue,
    );
    final later = List.generate(100, (_) => director.choose(150, [], random));
    expect(later, containsAll([4, 5]));
    final full = [
      for (var i = 0; i < 4; i++) TaskEnemy(Vector2.zero(), kind: 4),
      for (var i = 0; i < 2; i++) TaskEnemy(Vector2.zero(), kind: 5),
    ];
    expect(
      List.generate(
        100,
        (_) => director.choose(200, full, random),
      ).every((k) => k < 4),
      isTrue,
    );
  });
}
