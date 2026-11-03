import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

void main() {
  test('two random timer gaps stay separate and collision agrees with both openings', () {
    final random = Random(4);
    final separations = <int>{};
    for (var i = 0; i < 100; i++) {
      final pulse = TimerPulse(Vector2.zero(), TimerPulse.randomGaps(random))
        ..previousRadius = 198
        ..radius = 200;
      expect(pulse.gapAngles.length, 2);
      final separation = pulse.gapAngles[1] - pulse.gapAngles[0];
      expect(
        min(separation, 2 * pi - separation),
        greaterThan(TimerPulse.gapWidth),
      );
      separations.add((separation * 100).round());
      for (final gap in pulse.gapAngles) {
        expect(pulse.touches(Vector2(cos(gap), sin(gap)) * 200, 13), isFalse);
      }
      expect(
        TimerPulse.arcs(pulse.gapAngles).fold(0.0, (sum, a) => sum + a.$2),
        closeTo(pi * 2 - TimerPulse.gapWidth * 2, 0.001),
      );
    }
    expect(separations.length, greaterThan(50));
  });

  test('rush compositions favor their workload and respect specialist caps and total budget', () {
    const director = SpawnDirector();
    int samples(EnemyType type, RushTheme? theme) {
      final random = Random(18);
      return List.generate(
        1000,
        (_) => director.choose(225, [], random, theme: theme),
      ).where((kind) => kind == type.index).length;
    }

    for (final pair in [
      (EnemyType.rpc, RushTheme.memory),
      (EnemyType.forkBomb, RushTheme.forks),
      (EnemyType.memoryLeak, RushTheme.leaks),
      (EnemyType.timerEvent, RushTheme.timers),
    ]) {
      expect(samples(pair.$1, pair.$2), greaterThan(samples(pair.$1, null)));
    }
    for (final elapsed in [225.0, 250.0, 280.0]) {
      final random = Random(2);
      final enemies = <TaskEnemy>[];
      for (var i = 0; i < 500; i++) {
        final kind = director.choose(
          elapsed,
          enemies,
          random,
          theme: RushTheme.leaks,
        );
        final type = EnemyType.values[kind];
        final count = type == EnemyType.batch ? 4 : 1;
        enemies.addAll(
          List.generate(count, (_) => TaskEnemy(Vector2.zero(), kind: kind)),
        );
        final cost = SpawnDirector.rules.fold(
          0,
          (sum, rule) =>
              sum +
              rule.cost * enemies.where((e) => e.type == rule.type).length,
        );
        expect(
          cost,
          lessThanOrEqualTo(
            SpawnDirector.budgetLimit(elapsed, theme: RushTheme.leaks),
          ),
        );
        for (final rule in SpawnDirector.rules) {
          expect(
            enemies.where((e) => e.type == rule.type).length,
            lessThanOrEqualTo(SpawnDirector.typeLimit(rule, elapsed)),
          );
        }
      }
    }
  });

  test('final minute has escalating populations and durability; GC emits an identifiable effect', () {
    int population(double time) {
      final run = RunState(random: Random(2))
        ..start()
        ..enemies.clear()
        ..elapsed = time;
      for (var i = 0; i < 200; i++) {
        run.health = run.maxHealth;
        run.update(0.05);
      }
      expect(run.enemies.length, lessThanOrEqualTo(240));
      return run.enemies.length;
    }

    expect(population(270), greaterThan(population(240)));
    expect(population(240), greaterThan(population(210)));
    final run = RunState()
      ..start()
      ..enemies.clear();
    run.upgrades[Upgrade.garbageCollection] = 1;
    for (var i = 0; i < 61; i++) {
      run.update(0.05);
    }
    expect(
      run.effects.any((e) => e.collection && e.radius == run.gcRadius),
      isTrue,
    );
    expect(run.gcProgress, lessThan(0.1));
  });
}
