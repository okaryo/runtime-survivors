import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/deadlock_encounter.dart';

import 'run_state_test.dart' show tick;

RunState encounterRun() => RunState(random: Random(19))
  ..start()
  ..enemies.clear()
  ..elapsed = 74.99
  ..update(0.02);

void main() {
  test('locks gradually turn toward the player and remain between player and core', () {
    final core = TaskEnemy(
      Vector2.zero(),
      kind: EnemyType.deadlock.index,
      health: 3000,
    );
    final encounter = DeadlockEncounter(core);
    encounter.rebuild(Vector2(400, 0));
    encounter.warningRemaining = 0;
    final positions = encounter.nodes.map((n) => n.position.clone()).toList();
    final player = Vector2(0, 400);
    encounter.advance(0.05, player);
    // A sharp player turn cannot instantly sweep the barrier across the arena.
    for (var i = 0; i < positions.length; i++) {
      expect(
        encounter.nodes[i].position.distanceTo(positions[i]),
        lessThan(13),
      );
    }
    for (var frame = 0; frame < 60; frame++) {
      encounter.advance(0.05, player);
    }
    final forward = (player - core.position).normalized();
    final middle = encounter.nodes[1].position - core.position;
    expect(middle.normalized().dot(forward), closeTo(1, 0.001));
    for (final node in encounter.nodes) {
      final projection = (node.position - core.position).dot(forward);
      expect(projection, greaterThan(0));
      expect(projection, lessThan(player.distanceTo(core.position)));
    }
    expect(encounter.barriers.length, 4);
    encounter.breakDependency();
    expect(encounter.barriers, isEmpty);
    expect(encounter.nodes.every((n) => !n.alive), isTrue);
  });
  test(
    'deadlock pursues through its former stopping distance and makes contact',
    () {
      final run = RunState(random: Random(3))
        ..start()
        ..enemies.clear()
        ..spawnRadius = 10000;
      final core = TaskEnemy(
        Vector2(150, 0),
        kind: EnemyType.deadlock.index,
        health: 3000,
      );
      final encounter = DeadlockEncounter(core)..exposedRemaining = 5.5;
      run.enemies.add(core);
      run.deadlocks.add(encounter);
      tick(run, 3);
      expect(core.position.distanceTo(run.player), lessThan(core.radius + 13));
      expect(run.health, 78); // Core contact, without a beam hit masking it.
      final position = core.position.clone();
      run.pause();
      tick(run, 1);
      expect(core.position, position);
    },
  );
  test(
    'deadlock respects movement slow, follows with nodes and cannot overshoot',
    () {
      final core = TaskEnemy(Vector2(100, 0), kind: EnemyType.deadlock.index)
        ..movementMultiplier = 0.8;
      final encounter = DeadlockEncounter(core);
      encounter.rebuild(Vector2.zero());
      encounter.advance(1, Vector2.zero());
      expect(core.position.x, 68);
      for (final node in encounter.nodes) {
        expect(node.position, core.position + node.formationOffset);
      }
      core.position.setValues(0.1, 0);
      encounter.advance(0.05, Vector2.zero());
      expect(core.position, Vector2.zero());
      encounter.advance(0.05, Vector2.zero());
      expect(core.position, Vector2.zero());
    },
  );
  test('deadlock deploys a forward barricade, warns before damage and freezes on pause', () {
    final run = encounterRun();
    final encounter = run.deadlocks.single;
    expect(encounter.nodes.length, 3);
    final towardPlayer = run.player - encounter.core.position;
    for (final node in encounter.nodes) {
      final projection = (node.position - encounter.core.position).dot(
        towardPlayer.normalized(),
      );
      expect(projection, greaterThan(0));
      expect(projection, lessThan(towardPlayer.length));
      expect(node.maxHealth, greaterThan(250));
    }
    expect(run.lockBarriers.length, 4);
    expect(run.lockBarriers.every((b) => b.warning), isTrue);
    run.player.setFrom(encounter.nodes.first.position);
    run.update(0.01);
    expect(run.health, 100); // A rebuilding node cannot hit before its warning.
    final barrier = run.lockBarriers.first;
    run.player.setFrom((barrier.from + barrier.to) / 2);
    run.update(0.01);
    expect(run.health, 100);
    run.pause();
    final remaining = encounter.warningRemaining;
    tick(run, 2);
    expect(encounter.warningRemaining, remaining);
    run.resume();
    encounter.warningRemaining = 0;
    run.update(0.01);
    expect(run.health, 84);
    run.update(0.01);
    expect(
      run.health,
      84,
    ); // Shared invulnerability prevents repeated beam hits.
  });
  test(
    'any lock opens the cycle and later rebuilds in a different configuration',
    () {
      final run = encounterRun();
      final encounter = run.deadlocks.single;
      final core = encounter.core;
      final hp = core.health;
      run.instructions.clear();
      run.instructions.add(Instruction(core.position.clone(), core, 100));
      run.update(0.01);
      expect(core.health, closeTo(hp - 15, 0.001));
      run.instructions.clear();
      final node = encounter.nodes.first;
      run.instructions.add(Instruction(node.position.clone(), node, 10000));
      run.update(0.01);
      expect(encounter.exposed, isTrue);
      expect(run.lockBarriers, isEmpty);
      expect(encounter.nodes.every((n) => !n.alive), isTrue);
      final before = core.health;
      run.instructions.clear();
      run.instructions.add(Instruction(core.position.clone(), core, 100));
      run.update(0.01);
      expect(core.health, closeTo(before - 100, 0.001));
      core.health = core.maxHealth * 0.49;
      run.player.setFrom(core.position + Vector2(500, 0));
      for (var i = 0; i < 115; i++) {
        if (run.phase == RunPhase.choosing) run.choose(run.choices.first);
        run.health = run.maxHealth;
        run.update(0.05);
      }
      expect(encounter.cycle, 1);
      expect(encounter.exposed, isFalse);
      expect(encounter.nodes.where((n) => n.alive).length, 3);
      expect(run.lockBarriers.length, 4);
      final forward = (run.player - core.position).normalized();
      for (final node in encounter.nodes) {
        expect((node.position - core.position).dot(forward), greaterThan(0));
        expect(node.maxHealth, greaterThan(250));
      }
    },
  );
  test('processing the core clears all dependencies without phantom rewards or healing', () {
    final run = encounterRun()
      ..upgrades[Upgrade.ownership] = 1
      ..health = 50;
    final encounter = run.deadlocks.single;
    run.instructions.clear();
    run.instructions.add(
      Instruction(encounter.core.position.clone(), encounter.core, 100000),
    );
    run.update(0.01);
    expect(encounter.core.alive, isFalse);
    expect(run.lockBarriers, isEmpty);
    expect(encounter.nodes.every((n) => !n.alive), isTrue);
    expect(run.kills, 1);
    run.update(0.01);
    expect(run.deadlocks, isEmpty);
    run.start();
    expect(run.deadlocks, isEmpty);
    expect(run.lockBarriers, isEmpty);
  });
}
