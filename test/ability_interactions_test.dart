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
  test('ownership feedback reports actual recovery only and expires with game time', () {
    final run = prepared()..upgrades[Upgrade.ownership] = 1;
    run.enemies.add(TaskEnemy(Vector2(50, 0), health: 1));
    run.update(0.01);
    expect(run.recoveredMemory, 0); // A full-memory attack is not a recovery.
    run.health = 99.5;
    run.abilities.ownershipTimer = 0;
    run.enemies.add(TaskEnemy(Vector2(50, 0), health: 1));
    run.update(0.01);
    expect(run.health, 100);
    expect(run.recoveredMemory, 0.5);
    expect(run.recoveryLabel, '+0.5 MB');
    run.pause();
    tick(run, 2);
    expect(run.recoveredMemory, 0.5);
    run.resume();
    tick(run, 1);
    expect(run.recoveredMemory, 0);
  });
  test(
    'triggered deferred work damages later arrivals inside its fixed area',
    () {
      final run = prepared()..upgrades[Upgrade.lazyEvaluation] = 1;
      final trigger = TaskEnemy(Vector2(40, 0), kind: 3, health: 1000);
      run.enemies.add(trigger);
      tick(run, 0.4);
      expect(run.abilities.fields.single.triggered, isTrue);
      run.player.setValues(-800, 0);
      final arrival = TaskEnemy(Vector2(50, 0), kind: 3, health: 1000);
      final outside = TaskEnemy(Vector2(200, 0), kind: 3, health: 1000);
      run.enemies.addAll([arrival, outside]);
      tick(run, 0.65);
      expect(arrival.health, closeTo(986.4, 0.001));
      expect(outside.health, 1000);
      arrival.position.setValues(300, 0);
      tick(run, 0.65);
      expect(arrival.health, closeTo(986.4, 0.001));
    },
  );
  test('deferred traps wait for nearby work, burst, then damage and slow survivors and freeze on pause', () {
    final run = prepared()..upgrades[Upgrade.lazyEvaluation] = 1;
    run.update(0.01);
    final field = run.abilities.fields.single;
    expect(field.triggered, isFalse);
    final enemy = TaskEnemy(Vector2(60, 0), health: 1000);
    final elite = TaskEnemy(Vector2(-60, 0), kind: 3, health: 1000);
    run.enemies.addAll([enemy, elite]);
    tick(run, 0.36);
    expect(field.triggered, isTrue);
    expect(enemy.health, lessThanOrEqualTo(1000 - 68));
    expect(elite.health, lessThanOrEqualTo(932));
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
    tick(run, 0.7);
    expect(run.abilities.fields, isNotEmpty);
    expect(elite.health, lessThan(damagedHealth));
    tick(run, 1.8);
    expect(run.abilities.fields, isEmpty);
    final finalHealth = elite.health;
    tick(run, 0.7);
    expect(elite.health, finalHealth); // Expired fields cannot continue to hit.
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
    expect(run.health, 53);
    expect(run.recoveredMemory, 3);
    expect(run.recoveryLabel, '+3 MB');
    expect(
      run.effects
          .where((e) => e.recoveredMemory > 0)
          .every((e) => e.source != null),
      isTrue,
    );
    expect(run.kills, 7);
    expect(run.pickupRadius, 66);
    run.update(0.01);
    expect(run.kills, 7);
    run.resetToSetup();
    expect(run.recoveredMemory, 0);
    expect(run.abilities.fields, isEmpty);
    expect(run.abilities.exceptionCooldown, 0);
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
      (before.nullInterval, after.nullInterval),
      (before.ownershipInterval, after.ownershipInterval),
    ]) {
      expect(pair.$2, closeTo(pair.$1 * 0.92, 0.0001));
    }
    expect(after.shieldCooldown, before.shieldCooldown);
    expect(after.exceptionCooldown, before.exceptionCooldown);
    expect(after.exceptionPause, before.exceptionPause);
    expect(after.attackDamage, before.attackDamage);
    for (final infra in Upgrade.values.where((u) => !u.isFeature)) {
      expect(infra.maxRank, 6);
      final run = prepared()..upgrades[infra] = 6;
      expect(run.canUpgrade(infra), isFalse);
    }
    final run = prepared();
    expect(run.canUpgrade(Upgrade.pipeline), isFalse);
    expect(run.canUpgrade(Upgrade.spatialIndex), isTrue);
    expect(run.canUpgrade(Upgrade.coprocessor), isFalse);
    final budget = AbilityRuntime();
    expect(budget.claimHealing(10, 6), 6);
    expect(budget.claimHealing(10, 6), 0);
    budget.advance(1.1);
    expect(budget.claimHealing(10, 6), 6);
  });
}
