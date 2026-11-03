import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

void tick(RunState run, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    run.update(1 / 60);
  }
}

RunState freshRun() => RunState(random: Random(42))..start();

void grant(RunState run, Upgrade upgrade) {
  run.addExperience(run.nextLevelXp);
  run.choices = [upgrade];
  run.choose(upgrade);
}

void main() {
  test(
    'four infrastructure types exclude new types but allow invested upgrades',
    () {
      final run = freshRun();
      for (final infra in [
        Upgrade.memory,
        Upgrade.clock,
        Upgrade.cache,
        Upgrade.compiler,
      ]) {
        grant(run, infra);
      }
      expect(run.infraCount, RunState.infraSlots);
      for (var i = 0; i < 5; i++) {
        run.addExperience(run.nextLevelXp);
        expect(run.choices.length, 3);
        expect(run.choices.toSet().length, 3);
        expect(
          run.choices.every((u) => u.isFeature || run.rank(u) > 0),
          isTrue,
        );
        final oldHealth = run.health;
        run.choices = [Upgrade.pipeline];
        run.choose(Upgrade.pipeline);
        expect(run.rank(Upgrade.pipeline), 0);
        expect(run.health, oldHealth);
        expect(run.phase, RunPhase.choosing);
        run.choices = [Upgrade.memory];
        run.choose(Upgrade.memory);
      }
      expect(run.rank(Upgrade.memory), 6);
      expect(run.canUpgrade(Upgrade.memory), isFalse);
      run.resetToSetup();
      expect(run.infraCount, 0);
      expect(run.canUpgrade(Upgrade.pipeline), isFalse);
      expect(run.canUpgrade(Upgrade.compiler), isTrue);
    },
  );

  test('saturated builds offer remaining choices then recover memory without blocking', () {
    final run = freshRun();
    for (final feature in [
      Upgrade.garbageCollection,
      Upgrade.lazyEvaluation,
      Upgrade.oop,
      Upgrade.functional,
    ]) {
      run.upgrades[feature] = 4;
    }
    for (final infra in [
      Upgrade.spatialIndex,
      Upgrade.compiler,
      Upgrade.bandwidth,
      Upgrade.memoryProtection,
    ]) {
      run.upgrades[infra] = infra.maxRank;
    }
    run.upgrades[Upgrade.spatialIndex] = Upgrade.spatialIndex.maxRank - 1;
    run.upgrades[Upgrade.bandwidth] = Upgrade.bandwidth.maxRank - 1;
    run.addExperience(run.nextLevelXp);
    expect(run.choices.toSet(), {Upgrade.spatialIndex, Upgrade.bandwidth});
    run.choose(Upgrade.spatialIndex);
    run.addExperience(run.nextLevelXp);
    expect(run.choices, [Upgrade.bandwidth]);
    run.choose(Upgrade.bandwidth);
    run.health = 1;
    final oldLevel = run.level;
    run.addExperience(run.nextLevelXp + (run.nextLevelXp + 7) + 5);
    expect(run.level, oldLevel + 2);
    expect(run.xp, 5);
    expect(run.health, 71);
    expect(run.phase, RunPhase.running);
    expect(run.choices, isEmpty);
  });

  test('diagonal movement has the same speed and pause freezes combat', () {
    final run = freshRun()..movement.setValues(1, 1);
    run.update(0.05);
    expect(run.player.length, closeTo(run.speed * 0.05, 0.001));
    run.pause();
    final position = run.player.clone();
    final elapsed = run.elapsed;
    tick(run, 2);
    expect(run.player, position);
    expect(run.elapsed, elapsed);
    expect(run.movement.length2, 0);
  });

  test('enemies spawn, pursue and damage with an invulnerability window', () {
    final run = freshRun()..enemies.clear();
    final enemy = TaskEnemy(Vector2(5, 0), health: 500);
    run.enemies.add(enemy);
    run.update(0.01);
    expect(run.enemies.length, greaterThan(1));
    expect(enemy.position.x, lessThan(5));
    expect(run.health, 91);
    run.update(0.01);
    expect(run.health, 91);
    tick(run, 0.7);
    expect(run.health, lessThan(91));
  });

  test('automatic attack chooses nearest task and death drops experience', () {
    final run = freshRun()..enemies.clear();
    final far = TaskEnemy(Vector2(160, 0));
    final near = TaskEnemy(Vector2(80, 0));
    run.enemies.addAll([far, near]);
    run.update(0.01);
    expect(run.instructions.first.target, same(near));
    tick(run, 0.2);
    expect(near.alive, isFalse);
    expect(run.kills, 1);
    expect(run.experience, isNotEmpty);
    run.player.setFrom(run.experience.first.position);
    run.update(0.01);
    expect(run.xp, 4);
  });

  test(
    'level-up offers three unique choices and freezes time until selection',
    () {
      final run = freshRun();
      run.addExperience(run.nextLevelXp + 3);
      expect(run.phase, RunPhase.choosing);
      expect(run.level, 2);
      expect(run.xp, 3);
      expect(run.choices.toSet().length, 3);
      tick(run, 1);
      expect(run.elapsed, 0);
      final choice = run.choices.first;
      run.choose(choice);
      expect(run.phase, RunPhase.running);
      expect(run.rank(choice), 1);
      expect(run.choices, isEmpty);
    },
  );

  test(
    'excess experience queues further upgrades and invalid choices are ignored',
    () {
      final run = freshRun();
      run.addExperience(80);
      final oldChoices = run.choices.toList();
      final invalid = Upgrade.values.firstWhere((u) => !oldChoices.contains(u));
      run.choose(invalid);
      expect(run.rank(invalid), 0);
      run.choose(oldChoices.first);
      expect(run.phase, RunPhase.choosing);
      expect(run.level, 3);
      expect(run.choices.toSet().length, 3);
    },
  );

  test(
    'concurrency attacks multiple distinct tasks without reducing shot damage',
    () {
      final run = freshRun();
      grant(run, Upgrade.concurrency);
      run.enemies.clear();
      run.enemies.addAll([
        TaskEnemy(Vector2(100, 0)),
        TaskEnemy(Vector2(-100, 0)),
      ]);
      run.update(0.01);
      expect(run.instructions.length, 2);
      expect(run.instructions.map((s) => s.target).toSet().length, 2);
      expect(run.attackDamage, closeTo(22.08, 0.0001));
    },
  );

  test('garbage collection damages all nearby tasks, but not distant ones', () {
    final run = freshRun();
    grant(run, Upgrade.garbageCollection);
    run.enemies.clear();
    final near = TaskEnemy(Vector2(100, 0), health: 1000);
    final other = TaskEnemy(Vector2(-100, 0), health: 1000);
    final far = TaskEnemy(Vector2(300, 0), health: 1000);
    run.enemies.addAll([near, other, far]);
    tick(run, 0.65);
    expect(near.health, lessThan(1000));
    expect(other.health, lessThan(1000));
    expect(far.health, 1000);
    expect(run.effects.any((e) => e.pulse), isTrue);
    expect(run.attackInterval, 0.62);
  });

  test(
    'feature caps preserve three available choices, infrastructure can stack',
    () {
      final run = freshRun();
      for (final feature in Upgrade.values.where((u) => u.isFeature)) {
        run.upgrades[feature] = 4;
      }
      run.addExperience(run.nextLevelXp);
      expect(run.choices.length, 3);
      expect(run.choices.every((u) => !u.isFeature), isTrue);
      run.choices = [Upgrade.memory];
      run.health = 30;
      run.choose(Upgrade.memory);
      expect(run.maxHealth, 101); // Only OOP reserves memory.
      expect(run.health, 65);
    },
  );

  test('victory, defeat and restart leave no state from the previous run', () {
    final run = freshRun()..elapsed = 299.99;
    run.update(0.02);
    expect(run.phase, RunPhase.won);
    expect(run.timeLabel, '05:00');
    run.start();
    run.health = 1;
    run.enemies.add(TaskEnemy(Vector2.zero()));
    run.update(0.01);
    expect(run.phase, RunPhase.lost);
    run.upgrades[Upgrade.concurrency] = 3;
    run.start();
    expect(run.phase, RunPhase.running);
    expect(run.upgrades, isEmpty);
    expect(run.experience, isEmpty);
    expect(run.instructions, isEmpty);
    expect(run.health, 100);
    expect(run.elapsed, 0);
    expect(run.kills, 0);
    expect(run.level, 1);
  });
}
