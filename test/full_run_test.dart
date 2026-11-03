import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/spawn_director.dart';

void main() {
  final loadouts = [
    [
      Upgrade.lazyEvaluation,
      Upgrade.garbageCollection,
      Upgrade.functional,
      Upgrade.ownership,
    ],
    [
      Upgrade.ownership,
      Upgrade.functional,
      Upgrade.oop,
      Upgrade.jitCompilation,
    ],
    [
      Upgrade.concurrency,
      Upgrade.exceptionHandling,
      Upgrade.jitCompilation,
      Upgrade.patternMatching,
    ],
    [
      Upgrade.asyncStream,
      Upgrade.functional,
      Upgrade.ownership,
      Upgrade.exceptionHandling,
    ],
  ];
  for (var i = 0; i < loadouts.length; i++) {
    test(
      'five-minute interaction loadout $i stays bounded and resets all ability state',
      () {
        final run = RunState(random: Random(91 + i))..start();
        run.upgrades.addAll({for (final feature in loadouts[i]) feature: 4});
        final infrastructure = [
          [
            Upgrade.spatialIndex,
            Upgrade.compiler,
            Upgrade.memory,
            Upgrade.clock,
          ],
          [
            Upgrade.spatialIndex,
            Upgrade.memoryProtection,
            Upgrade.memory,
            Upgrade.compiler,
          ],
          [
            Upgrade.bandwidth,
            Upgrade.compiler,
            Upgrade.memoryProtection,
            Upgrade.clock,
          ],
          [
            Upgrade.compiler,
            Upgrade.spatialIndex,
            Upgrade.memory,
            Upgrade.clock,
          ],
        ];
        run.upgrades.addAll({for (final infra in infrastructure[i]) infra: 6});
        for (
          var frame = 0;
          frame < 6010 && run.phase != RunPhase.won;
          frame++
        ) {
          if (run.phase == RunPhase.choosing) run.choose(run.choices.first);
          run.health = run.maxHealth - 10;
          run.update(0.05);
          expect(run.enemies.length, lessThanOrEqualTo(240));
          expect(
            run.enemies.where((e) => e.alive && e.reinforced).length,
            lessThanOrEqualTo(SpawnDirector.reinforcedLimit(run.elapsed)),
          );
          expect(run.projectiles.length, lessThanOrEqualTo(108));
          expect(
            run.instructions.length,
            lessThanOrEqualTo(RunState.instructionLimit),
          );
          expect(run.abilities.fields.length, lessThanOrEqualTo(3));
          expect(run.hazards.length, lessThanOrEqualTo(24));
          expect(
            run.leakPatches.length,
            lessThanOrEqualTo(MemoryLeakPatch.limit),
          );
          expect(run.timerPulses.length, lessThanOrEqualTo(TimerPulse.limit));
          expect(run.health, lessThanOrEqualTo(run.maxHealth));
        }
        expect(run.phase, RunPhase.won);
        run.resetToSetup();
        expect(run.abilities.exceptionCooldown, 0);
        expect(run.abilities.exceptionPause, 0);
        expect(run.abilities.fields, isEmpty);
        expect(run.abilities.jitCharge, 0);
        expect(run.hazards, isEmpty);
        expect(run.leakPatches, isEmpty);
        expect(run.timerPulses, isEmpty);
        expect(run.abilities.streams.first.target, isNull);
      },
    );
  }
  for (final seed in [45, 82]) {
    test(
      'seeded five-minute $seed run keeps combat populations bounded and resets cleanly',
      () {
        final run = RunState(random: Random(seed))..start();
        for (
          var frame = 0;
          frame < 6010 && run.phase != RunPhase.won;
          frame++
        ) {
          if (run.phase == RunPhase.choosing) run.choose(run.choices.first);
          // Exercise all wave boundaries without ending this simulation on damage.
          run.health = run.maxHealth;
          run.update(0.05);
          expect(run.enemies.length, lessThanOrEqualTo(240));
          expect(
            run.enemies.where((e) => e.alive && e.reinforced).length,
            lessThanOrEqualTo(SpawnDirector.reinforcedLimit(run.elapsed)),
          );
          expect(run.projectiles.length, lessThanOrEqualTo(108));
          expect(run.featureCount, lessThanOrEqualTo(RunState.featureSlots));
          expect(run.infraCount, lessThanOrEqualTo(RunState.infraSlots));
          expect(
            run.instructions.length,
            lessThanOrEqualTo(RunState.instructionLimit),
          );
          expect(run.abilities.fields.length, lessThanOrEqualTo(3));
          expect(run.hazards.length, lessThanOrEqualTo(24));
          expect(
            run.leakPatches.length,
            lessThanOrEqualTo(MemoryLeakPatch.limit),
          );
          expect(run.timerPulses.length, lessThanOrEqualTo(TimerPulse.limit));
        }
        expect(run.phase, RunPhase.won);
        expect(run.seenEnemies, containsAll([2, 4, 5, 11, 13, 14]));
        expect(run.rushCount, 6);
        run.start();
        expect(run.projectiles, isEmpty);
        expect(run.deadlocks, isEmpty);
        expect(run.upgrades, isEmpty);
        expect(run.health, 100);
      },
    );
  }
}
