import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

void main() {
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
