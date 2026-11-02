import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show tick, grant;

RunState prepared() => RunState(random: Random(17))
  ..start()
  ..enemies.clear();

void main() {
  test(
    'choices mix features and infrastructure until all features are capped',
    () {
      final run = prepared();
      for (var i = 0; i < 80; i++) {
        run.phase = RunPhase.running;
        run.xp = 0;
        run.addExperience(run.nextLevelXp);
        expect(run.choices.length, 3);
        expect(run.choices.toSet().length, 3);
        expect(run.choices.any((u) => u.isFeature), isTrue);
        expect(run.choices.any((u) => !u.isFeature), isTrue);
      }
    },
  );

  test('OOP objects orbit, attack independently without reducing memory', () {
    final run = prepared();
    grant(run, Upgrade.oop);
    expect(run.maxHealth, 100);
    expect(run.health, 100);
    final target = TaskEnemy(Vector2(200, 0), health: 1000);
    run.enemies.add(target);
    tick(run, 0.1);
    expect(run.objects.length, 1);
    expect(
      run.objects.first.position.distanceTo(run.player),
      closeTo(72, 0.01),
    );
    expect(
      run.instructions.any((s) => s.kind == InstructionKind.object),
      isTrue,
    );
    tick(run, 0.3);
    expect(target.health, lessThan(1000 - run.attackDamage));
  });

  test(
    'functional attacks chain with damage falloff and never revisit a task',
    () {
      final run = prepared();
      grant(run, Upgrade.functional);
      final first = TaskEnemy(Vector2(90, 0), health: 1000);
      final second = TaskEnemy(Vector2(190, 0), health: 1000);
      final far = TaskEnemy(Vector2(440, 0), health: 1000);
      run.enemies.addAll([first, second, far]);
      tick(run, 0.45);
      expect(first.health, closeTo(1000 - run.attackDamage, 0.001));
      expect(second.health, closeTo(1000 - run.attackDamage * 0.7, 0.001));
      expect(far.health, 1000);
      expect(run.attackRange, 300);
    },
  );

  test(
    'scheduled rushes occur once per boundary and pause freezes the wave',
    () {
      final run = prepared()..elapsed = 44.98;
      run.update(0.03);
      expect(run.rushCount, 1);
      expect(run.isRush, isTrue);
      expect(run.enemies.length, greaterThanOrEqualTo(21));
      final count = run.enemies.length;
      run.update(0.01);
      expect(run.rushCount, 1);
      expect(run.enemies.length, count);
      run.pause();
      tick(run, 15);
      expect(run.isRush, isTrue);
      run.resume();
      run.elapsed = 54.1;
      run.update(0.01);
      expect(run.isRush, isFalse);
    },
  );

  test('scheduled deadlock creates a core and linked lock nodes', () {
    final run = prepared()..elapsed = 74.98;
    run.update(0.03);
    expect(run.deadlockCount, 1);
    expect(run.deadlocks.single.core.maxHealth, greaterThan(900));
    expect(run.deadlocks.single.nodes.length, 3);
    expect(run.lockBarriers.length, 2);
    expect(run.seenEnemies, contains(3));
  });

  test('restart clears combat additions but retains discoveries', () {
    final run = prepared();
    grant(run, Upgrade.oop);
    run.elapsed = 75;
    run.update(0.02);
    expect(run.objects, isNotEmpty);
    run.start();
    expect(run.objects, isEmpty);
    expect(run.rushCount, 0);
    expect(run.deadlockCount, 0);
    expect(run.isRush, isFalse);
    expect(run.maxHealth, 100);
    expect(run.seenUpgrades, contains(Upgrade.oop));
    expect(run.seenEnemies, contains(3));
  });
}
