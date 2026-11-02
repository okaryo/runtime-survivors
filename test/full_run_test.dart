import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

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
      Upgrade.nullSafety,
      Upgrade.oop,
      Upgrade.jitCompilation,
    ],
    [
      Upgrade.concurrency,
      Upgrade.memoization,
      Upgrade.jitCompilation,
      Upgrade.patternMatching,
    ],
  ];
  for (var i = 0; i < loadouts.length; i++) {
    test(
      'five-minute interaction loadout $i stays bounded and resets all ability state',
      () {
        final run = RunState(random: Random(91 + i))
          ..start(policy: TypingPolicy.values[i % 2]);
        run.upgrades.addAll({for (final feature in loadouts[i]) feature: 4});
        for (final infra in Upgrade.values.where((u) => !u.isFeature)) {
          if (infra.requiresAny.isEmpty ||
              infra.requiresAny.any((f) => run.rank(f) > 0)) {
            run.upgrades[infra] = 2;
          }
        }
        for (
          var frame = 0;
          frame < 6010 && run.phase != RunPhase.won;
          frame++
        ) {
          if (run.phase == RunPhase.choosing) run.choose(run.choices.first);
          run.health = run.maxHealth - 10;
          run.update(0.05);
          expect(run.enemies.length, lessThanOrEqualTo(240));
          expect(run.projectiles.length, lessThanOrEqualTo(108));
          expect(
            run.instructions.length,
            lessThanOrEqualTo(RunState.instructionLimit),
          );
          expect(run.abilities.echoes.length, lessThanOrEqualTo(32));
          expect(run.abilities.fields.length, lessThanOrEqualTo(3));
          expect(run.hazards.length, lessThanOrEqualTo(24));
          expect(run.health, lessThanOrEqualTo(run.maxHealth));
        }
        expect(run.phase, RunPhase.won);
        run.resetToSetup();
        expect(run.abilities.echoes, isEmpty);
        expect(run.abilities.fields, isEmpty);
        expect(run.abilities.focusStacks, 0);
        expect(run.hazards, isEmpty);
      },
    );
  }
  for (final policy in TypingPolicy.values) {
    test(
      'seeded five-minute $policy run keeps combat populations bounded and resets cleanly',
      () {
        final run = RunState(random: Random(45))..start(policy: policy);
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
          expect(run.projectiles.length, lessThanOrEqualTo(108));
          expect(run.featureCount, lessThanOrEqualTo(4));
          expect(
            run.instructions.length,
            lessThanOrEqualTo(RunState.instructionLimit),
          );
          expect(run.abilities.echoes.length, lessThanOrEqualTo(32));
          expect(run.abilities.fields.length, lessThanOrEqualTo(3));
          expect(run.hazards.length, lessThanOrEqualTo(24));
        }
        expect(run.phase, RunPhase.won);
        expect(run.seenEnemies, containsAll([4, 5, 6, 7, 8]));
        expect(run.rushCount, 6);
        run.start(policy: policy);
        expect(run.projectiles, isEmpty);
        expect(run.dynamicTimer, 0);
        expect(run.shieldTimer, 0);
        expect(run.upgrades, isEmpty);
        expect(run.health, 100);
      },
    );
  }
}
