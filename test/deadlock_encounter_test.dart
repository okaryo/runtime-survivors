import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show tick;

RunState encounterRun() => RunState(random: Random(19))
  ..start()
  ..enemies.clear()
  ..elapsed = 74.99
  ..update(0.02);

void main() {
  test(
    'deadlock always leaves an exit, warns before damage and freezes on pause',
    () {
      final run = encounterRun();
      final encounter = run.deadlocks.single;
      expect(encounter.nodes.length, 3);
      expect(run.lockBarriers.length, 2);
      expect(run.lockBarriers.every((b) => b.warning), isTrue);
      run.player.setFrom(encounter.nodes.first.position);
      run.update(0.01);
      expect(
        run.health,
        100,
      ); // A rebuilding node cannot hit before its warning.
      final barrier = run.lockBarriers.first;
      run.player.setFrom((barrier.from + barrier.to) / 2);
      run.update(0.01);
      expect(run.health, 100);
      run.pause();
      final remaining = encounter.warningRemaining;
      tick(run, 2);
      expect(encounter.warningRemaining, remaining);
      run.resume();
      encounter.warningRemaining = 0;
      run.update(0.01);
      expect(run.health, 84);
      run.update(0.01);
      expect(
        run.health,
        84,
      ); // Shared invulnerability prevents repeated beam hits.
    },
  );
  test(
    'any lock opens the cycle and later rebuilds in a different configuration',
    () {
      final run = encounterRun();
      final encounter = run.deadlocks.single;
      final core = encounter.core;
      final hp = core.health;
      run.instructions.clear();
      run.instructions.add(Instruction(core.position.clone(), core, 100));
      run.update(0.01);
      expect(core.health, closeTo(hp - 35, 0.001));
      run.instructions.clear();
      final node = encounter.nodes.first;
      run.instructions.add(Instruction(node.position.clone(), node, 10000));
      run.update(0.01);
      expect(encounter.exposed, isTrue);
      expect(run.lockBarriers, isEmpty);
      expect(encounter.nodes.every((n) => !n.alive), isTrue);
      final before = core.health;
      run.instructions.clear();
      run.instructions.add(Instruction(core.position.clone(), core, 100));
      run.update(0.01);
      expect(core.health, closeTo(before - 100, 0.001));
      core.health = core.maxHealth * 0.49;
      run.player.setFrom(core.position + Vector2(500, 0));
      for (var i = 0; i < 145; i++) {
        if (run.phase == RunPhase.choosing) run.choose(run.choices.first);
        run.health = run.maxHealth;
        run.update(0.05);
      }
      expect(encounter.cycle, 1);
      expect(encounter.exposed, isFalse);
      expect(encounter.nodes.where((n) => n.alive).length, 3);
      expect(run.lockBarriers.length, 2);
      expect(
        encounter.nodes.first.position.distanceTo(core.position),
        closeTo(175, 0.001),
      );
    },
  );
  test('processing the core clears all dependencies without phantom rewards or healing', () {
    final run = encounterRun()
      ..upgrades[Upgrade.ownership] = 1
      ..health = 50;
    final encounter = run.deadlocks.single;
    run.instructions.clear();
    run.instructions.add(
      Instruction(encounter.core.position.clone(), encounter.core, 100000),
    );
    run.update(0.01);
    expect(encounter.core.alive, isFalse);
    expect(run.lockBarriers, isEmpty);
    expect(encounter.nodes.every((n) => !n.alive), isTrue);
    expect(run.kills, 1);
    run.update(0.01);
    expect(run.deadlocks, isEmpty);
    run.start();
    expect(run.deadlocks, isEmpty);
    expect(run.lockBarriers, isEmpty);
  });
}
