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
  test('slow fields stay at their placement point and apply the strongest slow, with an elite floor', () {
    final run = prepared()..upgrades[Upgrade.lazyEvaluation] = 1;
    final enemy = TaskEnemy(Vector2(90, 0), health: 99999);
    final elite = TaskEnemy(Vector2(90, 0), kind: 3, health: 99999);
    run.enemies.addAll([enemy, elite]);
    run.update(0.01);
    expect(enemy.movementMultiplier, closeTo(0.7, 0.0001));
    expect(elite.movementMultiplier, 0.8);
    final field = run.abilities.fields.single;
    run.abilities.fields.add(SlowField(Vector2.zero(), 110, 0.6));
    run.update(0.01);
    expect(enemy.movementMultiplier, 0.6);
    run.player.setValues(-300, 0);
    expect(field.position, Vector2.zero());
    run.pause();
    final remaining = field.remaining;
    tick(run, 8);
    expect(field.remaining, remaining);
    run.resume();
    tick(run, 3.6);
    expect(run.abilities.fields, isEmpty);
  });
  test(
    'memoized volleys snapshot damage and echoes cannot generate more echoes',
    () {
      final run = prepared()..upgrades[Upgrade.memoization] = 1;
      final target = TaskEnemy(Vector2(250, 0), health: 10000);
      run.enemies.add(target);
      run.update(0.01);
      expect(
        run.abilities.echoes.single.damage,
        closeTo(24 * 0.9 * 0.65, 0.0001),
      );
      run.instructions.add(
        Instruction(Vector2(240, 0), target, 1, kind: InstructionKind.echo),
      );
      tick(run, 0.3);
      expect(run.abilities.echoes.length, 1);
      run.upgrades[Upgrade.compiler] =
          3; // The queued shot retains its original value.
      expect(run.abilities.echoes.single.damage, closeTo(14.04, 0.0001));
      run.pause();
      final remaining = run.abilities.echoes.single.remaining;
      tick(run, 2);
      expect(run.abilities.echoes.single.remaining, remaining);
      run.resume();
      tick(run, 0.38);
      expect(
        run.instructions.any((s) => s.kind == InstructionKind.echo),
        isTrue,
      );
      expect(
        run.abilities.echoes.length,
        1,
      ); // Only the second base volley is pending.
    },
  );
  test('JIT grows on one primary target, ignores echoes, and resets on a switch or interruption', () {
    final run = prepared()
      ..upgrades[Upgrade.jitCompilation] = 1
      ..upgrades[Upgrade.memoization] = 1;
    final target = TaskEnemy(Vector2(250, 0), health: 99999);
    run.enemies.add(target);
    tick(run, 1.3);
    expect(run.abilities.focusStacks, 2);
    final other = TaskEnemy(Vector2(70, 0), health: 99999);
    run.enemies.add(other);
    tick(run, 0.62);
    expect(run.abilities.focusTarget, same(other));
    expect(run.abilities.focusStacks, 0);
    run.enemies.clear();
    tick(run, 2.1);
    expect(run.abilities.focusStacks, 0);
    expect(run.abilities.focusTarget, isNull);
  });
  test('Ownership healing has a shared budget, excludes summons, and cannot duplicate kill rewards', () {
    final run = prepared()
      ..upgrades[Upgrade.ownership] = 1
      ..health = 50;
    for (var i = 0; i < 6; i++) {
      run.enemies.add(TaskEnemy(Vector2(70 + i * 5, 0), health: 1));
    }
    run.enemies.add(TaskEnemy(Vector2(90, 0), health: 1, summoned: true));
    run.projectiles.add(
      LinearProjectile(
        Vector2(-150, 0),
        Vector2(6000, 0),
        damage: 999,
        hostile: false,
        radius: 10,
      ),
    );
    run.update(0.05);
    expect(run.health, 56);
    expect(run.kills, 7);
    expect(run.pickupRadius, 58);
    run.update(0.01);
    expect(run.kills, 7);
    run.resetToSetup();
    expect(run.abilities.fields, isEmpty);
    expect(run.abilities.echoes, isEmpty);
    expect(run.abilities.focusTarget, isNull);
  });
  test(
    'new infrastructure acts on its named systems and respects prerequisites',
    () {
      final stats = BuildStats.snapshot({
        Upgrade.spatialIndex: 1,
        Upgrade.coprocessor: 1,
        Upgrade.memoryProtection: 1,
      });
      expect(stats.gcRadius, closeTo(115 * 1.15, 0.0001));
      expect(stats.slowRadius, closeTo(90 * 1.15, 0.0001));
      expect(stats.objectInterval, closeTo(0.81, 0.0001));
      expect(stats.hitInvulnerability, closeTo(0.75, 0.0001));
      final run = prepared();
      for (var i = 0; i < 40; i++) {
        run.phase = RunPhase.running;
        run.xp = 0;
        run.addExperience(run.nextLevelXp);
        expect(run.choices.contains(Upgrade.spatialIndex), isFalse);
        expect(run.choices.contains(Upgrade.coprocessor), isFalse);
      }
      final budget = AbilityRuntime();
      expect(budget.claimHealing(10, 6), 6);
      expect(budget.claimHealing(10, 6), 0);
      budget.advance(1.1);
      expect(budget.claimHealing(10, 6), 6);
    },
  );
}
