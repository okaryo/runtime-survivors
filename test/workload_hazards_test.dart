import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(71))
  ..start()
  ..spawnRadius = 10000
  ..enemies.clear();

void main() {
  test(
    'leak collision follows occupied squares and leaves missing corners safe',
    () {
      final source = TaskEnemy(
        Vector2(300, 0),
        kind: EnemyType.memoryLeak.index,
      );
      for (
        var pattern = 0;
        pattern < MemoryLeakPatch.layouts.length;
        pattern++
      ) {
        final patch = MemoryLeakPatch(Vector2.zero(), source, pattern: pattern);
        for (final cell in patch.cells) {
          expect(
            patch.touches(Vector2(cell.$1 * 22.0, cell.$2 * 22.0), 0),
            isTrue,
          );
        }
      }
      final patch = MemoryLeakPatch(Vector2.zero(), source);
      expect(patch.touches(Vector2(-44, 44), 13), isFalse);
      expect(patch.touches(Vector2(68, 0), 13), isTrue);
      expect(patch.touches(Vector2(69, 0), 13), isFalse);
      expect(patch.active, isFalse);
      patch.advance(0.56, sourcePresent: true);
      expect(patch.active, isTrue);
    },
  );

  test('overlapping leaked cells share damage and invulnerability, and safe corners do not hurt', () {
    final run = prepared();
    final source = TaskEnemy(
      Vector2(350, 0),
      kind: EnemyType.memoryLeak.index,
      health: 10000,
    )..attackCooldown = 99;
    run.enemies.add(source);
    run.leakPatches.addAll(
      List.generate(3, (_) => MemoryLeakPatch(Vector2.zero(), source)..age = 1),
    );
    run.update(0.01);
    expect(run.health, 92);
    tick(run, 0.3);
    expect(run.health, 92);
    run.player.setValues(-44, 44);
    tick(run, 0.5);
    expect(run.health, 92);
    run.player.setZero();
    run.update(0.01);
    expect(run.health, 84);
  });

  test('processing or despawning a leak source disarms and promptly clears its remaining patches', () {
    for (final despawn in [false, true]) {
      final run = prepared();
      final source = TaskEnemy(
        Vector2(200, 0),
        kind: EnemyType.memoryLeak.index,
        health: 1000,
      )..attackCooldown = 99;
      run.enemies.add(source);
      final patch = MemoryLeakPatch(Vector2.zero(), source)..age = 1;
      run.leakPatches.add(patch);
      if (despawn) {
        run.enemies.remove(source);
      } else {
        source.health = 1;
        run.invulnerability = 1;
        run.instructions.add(Instruction(source.position.clone(), source, 1));
        run.update(0.01);
        expect(source.alive, isFalse);
      }
      run.invulnerability = 0;
      run.update(0.01);
      expect(patch.cleaning, isTrue);
      expect(patch.active, isFalse);
      expect(run.health, 100);
      expect(patch.remaining, lessThanOrEqualTo(MemoryLeakPatch.cleanupTime));
      tick(run, 1.3);
      expect(run.leakPatches, isEmpty);
    }
  });

  test(
    'leak sources place bounded patches, and expiry permits new placements',
    () {
      final run = prepared();
      final sources = List.generate(
        6,
        (i) => TaskEnemy(
          Vector2(250, i * 10.0),
          kind: EnemyType.memoryLeak.index,
          health: 100000,
        ),
      );
      run.enemies.addAll(sources);
      var placed = false;
      for (var frame = 0; frame < 1000; frame++) {
        for (final source in sources) {
          source.position.setValues(250, 0);
          source.attackCooldown = 0;
        }
        run.instructions.clear();
        run.update(1 / 60);
        placed |= run.leakPatches.isNotEmpty;
        expect(
          run.leakPatches.length,
          lessThanOrEqualTo(MemoryLeakPatch.limit),
        );
        for (final source in sources) {
          expect(
            run.leakPatches.where((p) => identical(p.source, source)).length,
            lessThanOrEqualTo(MemoryLeakPatch.perSourceLimit),
          );
        }
      }
      expect(placed, isTrue);
      expect(run.leakPatches, isNotEmpty);
      expect(
        run.leakPatches.every((p) => p.age < MemoryLeakPatch.lifetime),
        isTrue,
      );
    },
  );

  test(
    'pulse collision sweeps the ring, leaves its interior and open sector safe',
    () {
      final pulse = TimerPulse(Vector2.zero(), [0, pi * 1.3])
        ..previousRadius = 90
        ..radius = 100;
      expect(pulse.touches(Vector2(-95, 0), 13), isTrue);
      expect(pulse.touches(Vector2(-115, 0), 13), isTrue);
      expect(pulse.touches(Vector2(-118, 0), 13), isFalse);
      expect(pulse.touches(Vector2.zero(), 13), isFalse);
      expect(pulse.touches(Vector2(95, 0), 13), isFalse);
      // Near the gap tip, the drawn rounded end still collides.
      final edge = TimerPulse.gapWidth / 2 - 0.03;
      expect(pulse.touches(Vector2(cos(edge), sin(edge)) * 95, 13), isTrue);
      pulse.advance(0.05);
      expect(pulse.touches(Vector2(-103, 0), 0), isTrue);
    },
  );

  test('timer counts down at a fixed position, fires one pulse, waits, and stops emitting when killed', () {
    final run = prepared();
    final timer = TaskEnemy(
      Vector2(240, 0),
      kind: EnemyType.timerEvent.index,
      health: 100000,
    )..attackCooldown = 0;
    run.enemies.add(timer);
    run.update(0.01);
    expect(timer.telegraphRemaining, TimerPulse.windup);
    final position = timer.position.clone();
    final gaps = timer.pulseGaps.toList();
    tick(run, 0.9);
    expect(run.timerPulses, isEmpty);
    expect(timer.position, position);
    run.pause();
    final windup = timer.telegraphRemaining;
    tick(run, 2);
    expect(timer.telegraphRemaining, windup);
    run.resume();
    tick(run, 0.12);
    expect(run.timerPulses.length, 1);
    expect(
      run.timerPulses.single.gapAngles,
      orderedEquals(gaps.map((a) => a % (pi * 2)).toList()..sort()),
    );
    expect(timer.attackCooldown, greaterThan(4));
    timer.health = 0;
    tick(run, 2.3);
    expect(run.timerPulses, isEmpty);
    expect(timer.cycleCount, 1);
  });

  test('new hazards freeze during choices and reset without surviving into the next run', () {
    final run = prepared();
    final source = TaskEnemy(
      Vector2(300, 0),
      kind: EnemyType.memoryLeak.index,
      health: 1000,
    );
    run.enemies.add(source);
    final patch = MemoryLeakPatch(Vector2.zero(), source);
    final pulse = TimerPulse(Vector2(-200, 0), [pi, 0.7]);
    run.leakPatches.add(patch);
    run.timerPulses.add(pulse);
    run.addExperience(run.nextLevelXp);
    tick(run, 3);
    expect(patch.remaining, MemoryLeakPatch.lifetime);
    expect(pulse.radius, 24);
    run.start();
    expect(run.leakPatches, isEmpty);
    expect(run.timerPulses, isEmpty);
  });
}
