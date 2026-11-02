import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/combat_rules.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(9))
  ..start()
  ..enemies.clear();
void main() {
  test('directional armor mitigates frontal shots, while flanks and area attacks keep full damage', () {
    final target = TaskEnemy(
      Vector2.zero(),
      kind: EnemyType.armoredAllocation.index,
    )..facing.setValues(1, 0);
    expect(
      CombatRules.damage(target, 100, origin: Vector2(20, 0)),
      closeTo(55, 0.001),
    );
    expect(CombatRules.damage(target, 100, origin: Vector2(-20, 0)), 100);
    expect(CombatRules.damage(target, 100, origin: Vector2(0, 20)), 100);
    expect(
      CombatRules.damage(target, 100, origin: Vector2(20, 0), area: true),
      100,
    );
  });
  test('support auras do not stack and disappear when support dies', () {
    final run = prepared();
    final target = TaskEnemy(Vector2(100, 0), health: 99999);
    final a = TaskEnemy(Vector2(200, 0), kind: 7, health: 99999);
    final b = TaskEnemy(Vector2(210, 0), kind: 7, health: 99999);
    run.enemies.addAll([target, a, b]);
    run.update(0.01);
    expect(target.movementMultiplier, 1.25);
    expect(target.attackRate, 1.15);
    expect(a.supported, isFalse);
    a.health = 0;
    b.health = 0;
    run.update(0.01);
    expect(target.supported, isFalse);
    expect(target.movementMultiplier, 1);
  });
  test('death blast is telegraphed, pause freezes it, and moving out avoids damage', () {
    final run = prepared();
    run.enemies.add(TaskEnemy(Vector2(60, 0), kind: 6, health: 1));
    tick(run, 0.2);
    expect(run.hazards.length, 1);
    final hazard = run.hazards.single;
    run.pause();
    final remaining = hazard.remaining;
    tick(run, 3);
    expect(hazard.remaining, remaining);
    run.resume();
    run.player.setValues(-200, 0);
    tick(run, 1.2);
    expect(run.health, 100);
    expect(run.hazards, isEmpty);
    run.hazards.add(DangerZone(run.player.clone(), warning: 0.02));
    run.update(0.03);
    expect(run.health, 82);
    run.resetToSetup();
    expect(run.hazards, isEmpty);
  });
  test(
    'new specialist roles have staged introductions and a shared budget',
    () {
      const director = SpawnDirector();
      final random = Random(6);
      expect(
        List.generate(
          200,
          (_) => director.choose(60, [], random),
        ).every((k) => k < 6 || k == 10),
        isTrue,
      );
      final late = List.generate(500, (_) => director.choose(220, [], random));
      expect(late, containsAll([6, 7, 8]));
      for (final rule in SpawnDirector.rules) {
        final capped = [
          for (var i = 0; i < rule.limit; i++)
            TaskEnemy(Vector2.zero(), kind: rule.type.index),
        ];
        expect(
          List.generate(
            100,
            (_) => director.choose(220, capped, random),
          ).contains(rule.type.index),
          isFalse,
        );
      }
    },
  );
  test('duplicate requests share an input and director reserves the whole pair budget', () {
    final run = prepared()..elapsed = 30;
    run.update(0.01);
    final pair = run.enemies
        .where((e) => e.type == EnemyType.duplicateRequest)
        .toList();
    expect(pair.length, 2);
    expect(pair.first.inputSignature, pair.last.inputSignature);
    const director = SpawnDirector();
    expect(
      SpawnDirector.rules.fold(
        0,
        (sum, rule) => sum + rule.cost * rule.batchSize,
      ),
      lessThanOrEqualTo(18),
    );
    final occupied = [
      for (var i = 0; i < 3; i++) TaskEnemy(Vector2.zero(), kind: 4),
      for (var i = 0; i < 2; i++) TaskEnemy(Vector2.zero(), kind: 5),
    ]; // Cost 17 leaves no room for a two-task batch.
    for (var seed = 0; seed < 100; seed++) {
      expect(director.choose(220, occupied, Random(seed)), isNot(10));
    }
  });
}
