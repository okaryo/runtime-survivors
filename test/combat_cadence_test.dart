import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/ability_runtime.dart';
import 'package:runtime_survivors/game/run_state.dart';

// Fixed, durable targets isolate attack cadence from kills, movement and choices.
double sustainedDamage(Map<Upgrade, int> ranks, int fps) {
  final run = RunState(random: Random(17))
    ..start()
    ..enemies.clear()
    ..spawnRadius = 100000;
  run.upgrades.addAll(ranks);
  final targets = [
    for (var i = 0; i < 8; i++)
      TaskEnemy(
        Vector2(55 + i * 8.0, 0),
        kind: EnemyType.lockNode.index,
        health: 10000000,
      ),
  ];
  double damage() => targets.fold(0.0, (n, e) => n + e.maxHealth - e.health);
  var warmupDamage = 0.0;
  for (var frame = 0; frame < fps * 30; frame++) {
    run.enemies
      ..clear()
      ..addAll(targets);
    // Keep exactly the same optimization level after per-frame decay.
    run.abilities.jitCharge = 60 + AbilityRuntime.jitDecay / fps;
    run.update(1 / fps);
    if (frame == fps * 5 - 1) warmupDamage = damage();
  }
  return (damage() - warmupDamage) / 25;
}

void main() {
  for (final feature in [
    null,
    Upgrade.oop,
    Upgrade.asyncStream,
    Upgrade.garbageCollection,
    Upgrade.patternMatching,
    Upgrade.lazyEvaluation,
    Upgrade.ownership,
    Upgrade.concurrency,
  ]) {
    test('$feature retains attack cadence across 30, 60 and 120 FPS', () {
      final ranks = {
        Upgrade.compiler: 6,
        if (feature != null) feature: 4,
        if (feature == Upgrade.concurrency) ...{
          Upgrade.functional: 4,
          Upgrade.jitCompilation: 4,
        },
      };
      final damages = [
        for (final fps in [30, 60, 120]) sustainedDamage(ranks, fps),
      ];
      expect(damages.reduce(min), greaterThan(0));
      expect(damages.reduce(max) / damages.reduce(min), lessThan(1.02));
    });
  }

  test('attacks resume without a backlog after an empty arena or a long ability pause', () {
    for (final blocked in [false, true]) {
      final run = RunState(random: Random(17))
        ..start()
        ..enemies.clear()
        ..spawnRadius = 100000
        ..upgrades[Upgrade.compiler] = 6;
      final target = TaskEnemy(
        Vector2(250, 0),
        kind: EnemyType.lockNode.index,
        health: 100000,
      );
      if (blocked) {
        run.enemies.add(target);
        run.abilities.gcPause = 2;
      }
      for (var frame = 0; frame < 120; frame++) {
        run.enemies
          ..clear()
          ..addAll(blocked ? [target] : <TaskEnemy>[]);
        run.instructions.clear();
        run.update(1 / 60);
      }
      run.enemies
        ..clear()
        ..add(target);
      final firedAt = <double>[];
      for (var frame = 0; frame < 90; frame++) {
        run.instructions.clear();
        run.update(1 / 60);
        if (run.instructions.any((shot) => shot.kind == InstructionKind.base)) {
          firedAt.add(run.elapsed);
        }
      }
      expect(firedAt.length, greaterThan(2));
      for (var i = 1; i < firedAt.length; i++) {
        expect(
          firedAt[i] - firedAt[i - 1],
          greaterThanOrEqualTo(run.attackInterval - 1 / 60 - 1e-9),
        );
      }
    }
  });

  test('lingering evaluation delivers its final tick at expiry at every frame rate', () {
    for (final fps in [30, 60, 120]) {
      final run = RunState(random: Random(17))
        ..start()
        ..enemies.clear()
        ..spawnRadius = 100000;
      run.abilities.exceptionPause = 100;
      final target = TaskEnemy(
        Vector2(50, 0),
        kind: EnemyType.lockNode.index,
        health: 1000,
      );
      run.enemies.add(target);
      run.abilities.fields.add(
        SlowField(Vector2.zero(), 100, 0.7, damage: 100)
          ..triggered = true
          ..remaining = SlowField.activeDuration,
      );
      for (var frame = 0; frame < (fps * 2.5).ceil(); frame++) {
        run.update(1 / fps);
      }
      expect(target.health, closeTo(920, 1e-6));
      expect(run.abilities.fields, isEmpty);
    }
  });
}
