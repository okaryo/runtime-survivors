import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(191))
  ..start()
  ..enemies.clear()
  ..spawnRadius = 10000;

void main() {
  test('specialist durability grows after two minutes while common workloads retain their curve', () {
    expect(SpawnDirector.healthFor(EnemyType.rpc, 120), closeTo(103.2, 0.001));
    expect(SpawnDirector.healthFor(EnemyType.rpc, 180), closeTo(230.4, 0.001));
    expect(SpawnDirector.healthFor(EnemyType.rpc, 240), closeTo(457.92, 0.001));
    expect(SpawnDirector.healthFor(EnemyType.rpc, 270), closeTo(675.99, 0.001));
    expect(
      SpawnDirector.healthFor(EnemyType.rpc, 180, reinforced: true),
      closeTo(506.88, 0.001),
    );
    expect(
      SpawnDirector.healthFor(EnemyType.memoryLeak, 180),
      closeTo(217.6, 0.001),
    );
    expect(SpawnDirector.healthFor(EnemyType.request, 180), 32);
    expect(SpawnDirector.healthFor(EnemyType.batch, 180), closeTo(36.8, 0.001));
    expect(SpawnDirector.healthFor(EnemyType.deadlock, 180), 2520);
  });

  test('promotion is limited by time, role, prior introduction and living global count', () {
    const director = SpawnDirector();
    final random = Random(9);
    final heavy = TaskEnemy(
      Vector2.zero(),
      kind: EnemyType.rpc.index,
      reinforced: true,
    );
    for (var i = 0; i < 200; i++) {
      expect(
        director.shouldReinforce(
          EnemyType.rpc,
          149.99,
          [],
          random,
          introduced: true,
        ),
        isFalse,
      );
      expect(
        director.shouldReinforce(
          EnemyType.rpc,
          200,
          [],
          random,
          introduced: false,
        ),
        isFalse,
      );
      expect(
        director.shouldReinforce(
          EnemyType.request,
          280,
          [],
          random,
          introduced: true,
        ),
        isFalse,
      );
      expect(
        director.shouldReinforce(
          EnemyType.rpc,
          200,
          [heavy],
          random,
          introduced: true,
        ),
        isFalse,
      );
      expect(
        director.shouldReinforce(
          EnemyType.rpc,
          280,
          [heavy, heavy],
          random,
          introduced: true,
        ),
        isFalse,
      );
    }
    final early = List.generate(
      300,
      (_) => director.shouldReinforce(
        EnemyType.rpc,
        180,
        [],
        random,
        introduced: true,
      ),
    );
    expect(early, containsAll([true, false]));
    expect(
      List.generate(
        100,
        (_) => director.shouldReinforce(
          EnemyType.rpc,
          250,
          [heavy],
          random,
          introduced: true,
        ),
      ),
      contains(true),
    );
    heavy.health = 0;
    expect(
      List.generate(
        100,
        (_) => director.shouldReinforce(
          EnemyType.memoryLeak,
          180,
          [heavy],
          random,
          introduced: true,
        ),
      ),
      contains(true),
    );
  });

  test('natural waves introduce ordinary roles first and never exceed the promotion cap', () {
    final run = prepared();
    final seen = <int>{};
    final firstVariants = <int, bool>{};
    for (var frame = 0; frame < 6001 && run.phase != RunPhase.won; frame++) {
      run.enemies.removeWhere((enemy) => !enemy.reinforced);
      for (final enemy in run.enemies) {
        enemy.health = enemy.maxHealth;
      }
      run.health = run.maxHealth;
      run.update(0.05);
      for (final enemy in run.enemies) {
        firstVariants.putIfAbsent(enemy.kind, () => enemy.reinforced);
        if (enemy.reinforced) {
          seen.add(enemy.kind);
          expect(enemy.summoned, isFalse);
          expect(enemy.type.isSpecialist, isTrue);
        }
      }
      expect(
        run.enemies.where((e) => e.alive && e.reinforced).length,
        lessThanOrEqualTo(SpawnDirector.reinforcedLimit(run.elapsed)),
      );
      expect(run.enemies.length, lessThanOrEqualTo(240));
    }
    expect(run.phase, RunPhase.won);
    expect(seen, isNotEmpty);
    expect(firstVariants.values.every((heavy) => !heavy), isTrue);
    run.start();
    expect(run.enemies.any((enemy) => enemy.reinforced), isFalse);
  });

  for (final heavy in [false, true]) {
    test(
      'RPC ${heavy ? 'high load' : 'normal'} fires before entering a maximized base targeting range',
      () {
        final run = prepared();
        run.upgrades.addAll({
          Upgrade.cache: 6,
          Upgrade.spatialIndex: 6,
          Upgrade.asyncStream: 4,
        });
        final rpc = TaskEnemy(
          Vector2(heavy ? 490 : 450, 0),
          kind: EnemyType.rpc.index,
          health: 100000,
          reinforced: heavy,
        );
        run.enemies.add(rpc);
        tick(run, 1.05);
        expect(
          rpc.position.distanceTo(run.player),
          greaterThan(run.attackRange),
        );
        expect(
          run.abilities.streams.every((stream) => stream.target == null),
          isTrue,
        );
        expect(
          run.projectiles.where((shot) => shot.hostile).length,
          heavy ? 2 : 1,
        );
      },
    );
    test(
      'timer ${heavy ? 'high load' : 'normal'} winds up where its first pulse can actually reach',
      () {
        final run = prepared();
        final timer = TaskEnemy(
          Vector2(heavy ? 350 : 310, 0),
          kind: EnemyType.timerEvent.index,
          health: 100000,
          reinforced: heavy,
        );
        run.enemies.add(timer);
        run.update(0.01);
        expect(timer.telegraphRemaining, TimerPulse.windup);
        final origin = timer.position.clone();
        tick(run, 1.02);
        final pulse = run.timerPulses.single;
        expect(pulse.position, origin);
        expect(pulse.gapAngles.length, 2);
        expect(pulse.limitRadius, greaterThan(origin.distanceTo(run.player)));
        expect(timer.attackCooldown, closeTo(heavy ? 3.28 : 4.38, 0.1));
      },
    );
    test(
      'fork parent ${heavy ? 'high load' : 'normal'} produces a distinct first brood without exceeding six descendants',
      () {
        final run = prepared();
        final root = TaskEnemy(
          Vector2(200, 0),
          kind: EnemyType.forkBomb.index,
          health: 100000,
          reinforced: heavy,
        );
        run.enemies.add(root);
        tick(run, 1.95);
        final children = run.enemies.where(
          (enemy) => identical(enemy.owner, root),
        );
        expect(children.length, heavy ? 3 : 2);
        expect(children.every((child) => !child.reinforced), isTrue);
      },
    );
  }

  test('high-load leaks draw and collide with larger cells and scatter more frequently', () {
    final run = prepared();
    final heavy = TaskEnemy(
      Vector2(205, 0),
      kind: EnemyType.memoryLeak.index,
      health: 100000,
      reinforced: true,
    );
    run.enemies.add(heavy);
    tick(run, 2.5);
    expect(run.leakPatches.length, 2);
    expect(run.leakPatches.every((patch) => patch.cellExtent == 28), isTrue);
    final ordinary = MemoryLeakPatch(
      Vector2.zero(),
      TaskEnemy(Vector2.zero(), kind: EnemyType.memoryLeak.index),
    );
    final larger = MemoryLeakPatch(Vector2.zero(), heavy);
    expect(ordinary.touches(Vector2(68, 0), 0), isFalse);
    expect(larger.touches(Vector2(68, 0), 0), isTrue);
    expect(larger.cellRect((2, 0)).width, larger.cellExtent);
  });

  test('prioritizing a high-load task pays additional XP and JIT without changing its discovery ID', () {
    final run = prepared()..upgrades[Upgrade.jitCompilation] = 1;
    final heavy = TaskEnemy(
      Vector2(200, 0),
      kind: EnemyType.rpc.index,
      health: 1,
      reinforced: true,
    );
    run.enemies.add(heavy);
    run.instructions.add(Instruction(heavy.position.clone(), heavy, 1));
    run.update(0.01);
    expect(run.kills, 1);
    expect(run.experience.single.value, 8);
    expect(run.jitCharge, 13.5);
    expect(heavy.radius, heavy.baseRadius * 1.25);
    expect(heavy.kind, EnemyType.rpc.index);
  });
}
