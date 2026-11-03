import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

RunState prepared() {
  final run = RunState(random: Random(25))
    ..start()
    ..spawnRadius = 100000
    ..invulnerability = 1000;
  run.abilities.exceptionPause =
      1000; // Observe living broods without base fire.
  run.update(0.01);
  run.enemies.clear();
  return run;
}

void main() {
  test(
    'first-generation copies keep reproducing even while touching the player',
    () {
      final run = prepared();
      final root = TaskEnemy(
        Vector2(200, 0),
        kind: EnemyType.forkBomb.index,
        health: 100000,
      )..attackCooldown = 1000;
      final copy = TaskEnemy(
        Vector2.zero(),
        kind: EnemyType.forkBomb.index,
        health: 100000,
        summoned: true,
        owner: root,
        generation: 1,
      )..attackCooldown = 0;
      run.enemies.addAll([root, copy]);
      for (var frame = 0; frame < 480; frame++) {
        run.update(1 / 60);
      }
      expect(run.enemies.where((e) => e.generation == 2).length, 2);
      expect(copy.position, run.player);
    },
  );
  for (final heavy in [false, true]) {
    test(
      'fork parent ($heavy) emits separated broods while previous copies remain alive',
      () {
        final run = prepared();
        final root = TaskEnemy(
          Vector2(200, 0),
          kind: EnemyType.forkBomb.index,
          health: 100000,
          reinforced: heavy,
        )..telegraphRemaining = 0.01;
        run.enemies.add(root);
        run.update(0.02);
        final first = run.enemies.where((e) => e.summoned).toList();
        expect(first.length, heavy ? 3 : 2);
        for (var i = 0; i < first.length; i++) {
          for (var j = i + 1; j < first.length; j++) {
            expect(
              first[i].position.distanceTo(first[j].position),
              greaterThan(40),
            );
          }
        }
        for (var frame = 0; frame < 1800; frame++) {
          run.enemies.removeWhere(
            (e) => !identical(e, root) && !identical(e.owner, root),
          );
          run.update(1 / 60);
        }
        expect(first.every((e) => e.alive && run.enemies.contains(e)), isTrue);
        final copies = run.enemies
            .where((e) => identical(e.owner, root))
            .toList();
        expect(copies.length, greaterThan(6));
        expect(copies.any((e) => e.generation == 2), isTrue);
        expect(copies.every((e) => e.generation <= 2), isTrue);
        final positions = copies.map((e) => e.position.clone()).toList();
        run.pause();
        run.update(0.05);
        expect(copies.map((e) => e.position).toList(), positions);
        run.resume();
        root.health = 0;
        final count = copies.length;
        for (var i = 0; i < 600; i++) {
          run.update(1 / 60);
        }
        expect(
          run.enemies.where((e) => identical(e.owner, root)).length,
          count,
        );
      },
    );
  }

  test('simultaneous broods share the arena cap and leave room for the boss encounter', () {
    final run = prepared();
    final parents = List.generate(
      2,
      (i) => TaskEnemy(
        Vector2(200, i * 100.0),
        kind: EnemyType.forkBomb.index,
        health: 100000,
        reinforced: true,
      )..telegraphRemaining = 0.01,
    );
    run.enemies.addAll([
      ...parents,
      for (var i = 0; i < 229; i++) TaskEnemy(Vector2(1000, 0), health: 100000),
    ]);
    run.update(0.02);
    expect(run.enemies.length, 232);
    expect(run.enemies.where((e) => e.summoned).length, 1);
    for (var i = 0; i < 600; i++) {
      run.update(1 / 60);
    }
    expect(run.enemies.length, lessThanOrEqualTo(232));
  });

  test(
    'living copies do not consume specialist budget or the parent type limit',
    () {
      final parent = TaskEnemy(Vector2.zero(), kind: EnemyType.forkBomb.index);
      final enemies = [
        parent,
        for (var i = 0; i < 80; i++)
          TaskEnemy(
            Vector2.zero(),
            kind: EnemyType.forkBomb.index,
            summoned: true,
            owner: parent,
          ),
      ];
      const director = SpawnDirector();
      final random = Random(25);
      final offered = List.generate(
        1000,
        (_) => director.choose(200, enemies, random),
      ).toSet();
      expect(
        offered,
        containsAll([
          EnemyType.forkBomb.index,
          EnemyType.rpc.index,
          EnemyType.timerEvent.index,
          EnemyType.memoryLeak.index,
        ]),
      );
      enemies.add(TaskEnemy(Vector2.zero(), kind: EnemyType.forkBomb.index));
      expect(
        List.generate(1000, (_) => director.choose(200, enemies, random)),
        isNot(contains(EnemyType.forkBomb.index)),
      );
    },
  );
}
