import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/ability_runtime.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(8))
  ..start()
  ..enemies.clear();
void main() {
  test('deferred traps wait for nearby work, burst once, then slow survivors and freeze on pause', () {
    final run = prepared()..upgrades[Upgrade.lazyEvaluation] = 1;
    run.update(0.01);
    final field = run.abilities.fields.single;
    expect(field.triggered, isFalse);
    final enemy = TaskEnemy(Vector2(60, 0), health: 1000);
    final elite = TaskEnemy(Vector2(-60, 0), kind: 3, health: 1000);
    run.enemies.addAll([enemy, elite]);
    tick(run, 0.36);
    expect(field.triggered, isTrue);
    expect(enemy.health, lessThanOrEqualTo(1000 - 46));
    expect(elite.health, lessThanOrEqualTo(954));
    final damagedHealth = elite.health;
    expect(enemy.movementMultiplier, closeTo(0.7, 0.0001));
    expect(elite.movementMultiplier, 0.8);
    run.player.setValues(-800, 0);
    expect(field.position, Vector2.zero());
    run.pause();
    final remaining = field.remaining;
    tick(run, 8);
    expect(field.remaining, remaining);
    run.resume();
    tick(run, 1.6);
    expect(run.abilities.fields, isEmpty);
    expect(elite.health, damagedHealth); // The trap cannot burst twice.
  });
  test('memoization stores operation plus input and reuses only matching completed results', () {
    final run = prepared()..upgrades[Upgrade.memoization] = 1;
    final completed = TaskEnemy(
      Vector2(240, 0),
      kind: 10,
      inputVariant: 1,
      health: 1,
    );
    run.enemies.add(completed);
    run.instructions.add(Instruction(completed.position.clone(), completed, 1));
    run.update(0.01);
    expect(run.abilities.cachedInputs, {completed.inputSignature});
    run.instructions.clear();
    final matching = TaskEnemy(
      Vector2(250, 0),
      kind: 10,
      inputVariant: 1,
      health: 1000,
    );
    final different = TaskEnemy(
      Vector2(200, 0),
      kind: 10,
      inputVariant: 2,
      health: 1000,
    );
    run.enemies.addAll([matching, different]);
    run.abilities.memoTimer = 0;
    run.update(0.01);
    final cached = run.instructions.singleWhere(
      (s) => s.kind == InstructionKind.cached,
    );
    expect(cached.target, same(matching));
    expect(cached.damage, 54);
    expect(
      run.abilities.cachedInputs.contains(different.inputSignature),
      isFalse,
    );
    final timer = run.abilities.memoTimer;
    run.pause();
    tick(run, 2);
    expect(run.abilities.memoTimer, timer);
    run.start();
    expect(run.abilities.cachedInputs, isEmpty);
  });
  test('JIT warms up across target changes and keeps optimization across idle periods', () {
    final run = prepared()..upgrades[Upgrade.jitCompilation] = 1;
    run.enemies.add(TaskEnemy(Vector2(250, 0), health: 99999));
    tick(run, 1.3);
    expect(run.abilities.jitExecutions, 3);
    run.enemies.clear();
    run.enemies.add(TaskEnemy(Vector2(-250, 0), health: 99999));
    tick(run, 1.3);
    expect(run.abilities.jitExecutions, greaterThan(3));
    tick(run, 2.2);
    expect(run.abilities.jitOptimized, isTrue);
    expect(run.attackInterval, closeTo(0.62 / 1.4, 0.0001));
    final preview = run.preview(Upgrade.compiler);
    expect(preview.before.attackInterval, run.attackInterval);
    expect(
      preview.after.attackInterval,
      closeTo(run.attackInterval * 0.92, 0.0001),
    );
    run.enemies.clear();
    tick(run, 2.1);
    expect(run.abilities.jitOptimized, isTrue);
    run.start();
    expect(run.abilities.jitExecutions, 0);
    expect(run.attackInterval, 0.62);
  });
  test('Ownership adds an attack and healing has a shared budget excluding summons', () {
    final run = prepared()
      ..upgrades[Upgrade.ownership] = 1
      ..health = 50;
    for (var i = 0; i < 6; i++) {
      run.enemies.add(TaskEnemy(Vector2(70 + i * 5, 0), health: 1));
    }
    run.enemies.add(TaskEnemy(Vector2(90, 0), health: 1, summoned: true));
    run.update(0.05);
    expect(run.health, 56);
    expect(run.kills, 7);
    expect(run.pickupRadius, 66);
    run.update(0.01);
    expect(run.kills, 7);
    run.resetToSetup();
    expect(run.abilities.fields, isEmpty);
    expect(run.abilities.cachedInputs, isEmpty);
  });
  test('all infrastructure caps at six and compiler speeds every attack family without altering recharge', () {
    final before = BuildStats.snapshot({Upgrade.oop: 1, Upgrade.nullSafety: 1});
    final after = BuildStats.snapshot({
      Upgrade.oop: 1,
      Upgrade.nullSafety: 1,
      Upgrade.compiler: 1,
    });
    for (final pair in [
      (before.attackInterval, after.attackInterval),
      (before.objectInterval, after.objectInterval),
      (before.gcInterval, after.gcInterval),
      (before.patternInterval, after.patternInterval),
      (before.lazyInterval, after.lazyInterval),
      (before.memoInterval, after.memoInterval),
      (before.nullInterval, after.nullInterval),
      (before.ownershipInterval, after.ownershipInterval),
    ]) {
      expect(pair.$2, closeTo(pair.$1 * 0.92, 0.0001));
    }
    expect(after.shieldCooldown, before.shieldCooldown);
    expect(after.attackDamage, before.attackDamage);
    for (final infra in Upgrade.values.where((u) => !u.isFeature)) {
      expect(infra.maxRank, 6);
      final run = prepared()..upgrades[infra] = 6;
      expect(run.canUpgrade(infra), isFalse);
    }
    final run = prepared();
    expect(run.canUpgrade(Upgrade.pipeline), isFalse);
    expect(run.canUpgrade(Upgrade.spatialIndex), isFalse);
    expect(run.canUpgrade(Upgrade.coprocessor), isFalse);
    final budget = AbilityRuntime();
    expect(budget.claimHealing(10, 6), 6);
    expect(budget.claimHealing(10, 6), 0);
    budget.advance(1.1);
    expect(budget.claimHealing(10, 6), 6);
  });
}
