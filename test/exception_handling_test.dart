import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/deadlock_encounter.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'run_state_test.dart' show tick, grant;

RunState prepared() => RunState(random: Random(17))
  ..start()
  ..enemies.clear()
  ..spawnRadius = 10000
  ..upgrades[Upgrade.exceptionHandling] = 1;

void hit(RunState run, {double damage = 20}) {
  run.projectiles.add(
    LinearProjectile(run.player.clone(), Vector2.zero(), damage: damage),
  );
  run.update(0.01);
}

void main() {
  test('exceptions replace memoization with a new ID and require an offensive feature', () {
    final run = RunState()..start();
    expect(Upgrade.memoization.index, 13);
    expect(Upgrade.asyncStream.index, 19);
    expect(Upgrade.exceptionHandling.index, 20);
    expect(Upgrade.memoization.isAvailable, isFalse);
    expect(run.canUpgrade(Upgrade.memoization), isFalse);
    expect(run.canUpgrade(Upgrade.exceptionHandling), isFalse);
    grant(run, Upgrade.memory);
    expect(run.canUpgrade(Upgrade.exceptionHandling), isFalse);
    grant(run, Upgrade.concurrency);
    expect(run.canUpgrade(Upgrade.exceptionHandling), isTrue);
    grant(run, Upgrade.exceptionHandling);
    expect(run.exceptionReady, isTrue);
    expect(run.maxHealth, 125); // No retired cache reservation.
    run.upgrades[Upgrade.exceptionHandling] = 4;
    expect(run.canUpgrade(Upgrade.exceptionHandling), isFalse);
    expect(
      Upgrade.values.where((u) => u.isAvailable && u.isFeature).length,
      10,
    );
  });

  test(
    'one catch reduces contact damage and counters only nearby tasks once',
    () {
      final run = prepared();
      final contact = TaskEnemy(Vector2.zero(), health: 1000);
      final near = TaskEnemy(Vector2(80, 0), health: 1000);
      final far = TaskEnemy(Vector2(180, 0), health: 1000);
      run.enemies.addAll([contact, near, far]);
      run.update(0.01);
      expect(run.health, closeTo(94.6, 0.001));
      expect(contact.health, 940);
      expect(near.health, 940);
      expect(far.health, 1000);
      expect(run.effects.where((e) => e.counter).length, 1);
      expect(run.exceptionReady, isFalse);
      expect(run.abilities.exceptionCooldown, 5);
      expect(run.abilities.exceptionPause, 0.25);
      run.update(0.01);
      expect(run.health, closeTo(94.6, 0.001));
      expect(near.health, 940);
      run.invulnerability = 0;
      run.enemies.clear();
      hit(run);
      expect(run.health, closeTo(74.6, 0.001)); // Full damage during recharge.
      expect(run.effects.where((e) => e.counter).length, 1);
    },
  );

  for (final source in ['projectile', 'leak', 'timer', 'barrier']) {
    test(
      '$source damage shares catch reduction and the same invulnerability window',
      () {
        final run = prepared();
        final damage = switch (source) {
          'projectile' => 20.0,
          'leak' => MemoryLeakPatch.damage,
          'timer' => TimerPulse.damage,
          _ => 16.0,
        };
        switch (source) {
          case 'projectile':
            run.projectiles.addAll([
              LinearProjectile(Vector2.zero(), Vector2.zero(), damage: damage),
              LinearProjectile(Vector2.zero(), Vector2.zero(), damage: damage),
            ]);
          case 'leak':
            final owner = TaskEnemy(
              Vector2(205, 0),
              kind: EnemyType.memoryLeak.index,
              health: 1000,
            );
            run.enemies.add(owner);
            run.leakPatches.add(
              MemoryLeakPatch(Vector2.zero(), owner)..age = 1,
            );
          case 'timer':
            run.timerPulses.add(
              TimerPulse(Vector2(80, 0), [pi, 0])
                ..radius = 75
                ..previousRadius = 74,
            );
            // Place the player on an occupied arc, away from either opening.
            run.player.setValues(80, 80);
          case 'barrier':
            final core = TaskEnemy(
              Vector2(200, 0),
              kind: EnemyType.deadlock.index,
              health: 3000,
            );
            final encounter = DeadlockEncounter(core);
            run.enemies.add(core);
            run.enemies.addAll(encounter.rebuild(run.player));
            encounter.warningRemaining = 0;
            run.deadlocks.add(encounter);
            run.player.setFrom(
              (encounter.nodes[0].position + encounter.nodes[1].position) / 2,
            );
        }
        run.update(0.01);
        expect(run.health, closeTo(100 - damage * 0.6, 0.001));
        expect(run.effects.where((e) => e.counter).length, 1);
        run.update(0.01);
        expect(run.health, closeTo(100 - damage * 0.6, 0.001));
      },
    );
  }

  test('counter pause affects base firing while movement and object attacks continue', () {
    final run = prepared()..upgrades[Upgrade.oop] = 1;
    run.health = run.maxHealth;
    final target = TaskEnemy(Vector2(220, 0), health: 100000);
    run.enemies.add(target);
    hit(run);
    run.instructions.clear();
    run.objects.single.attackTimer = 0;
    run.movement.setValues(0, 1);
    final before = run.player.clone();
    tick(run, 0.1);
    expect(run.player.distanceTo(before), greaterThan(0));
    expect(
      run.instructions.where((s) => s.kind == InstructionKind.base),
      isEmpty,
    );
    expect(
      run.instructions.where((s) => s.kind == InstructionKind.object),
      isNotEmpty,
    );
    tick(run, 0.2);
    expect(run.abilities.exceptionPause, 0);
    expect(
      run.instructions.where((s) => s.kind == InstructionKind.base),
      isNotEmpty,
    );
  });

  test('catch recharge and feedback freeze on pause and choices, then reset with the run', () {
    final run = prepared();
    hit(run);
    final cooldown = run.abilities.exceptionCooldown;
    final effect = run.effects.singleWhere((e) => e.counter);
    final life = effect.life;
    run.pause();
    tick(run, 8);
    expect(run.abilities.exceptionCooldown, cooldown);
    expect(effect.life, life);
    run.resume();
    run.addExperience(run.nextLevelXp);
    tick(run, 8);
    expect(run.abilities.exceptionCooldown, cooldown);
    run.choices = [Upgrade.concurrency];
    run.choose(Upgrade.concurrency);
    tick(run, 5.1);
    expect(run.exceptionReady, isTrue);
    expect(run.effects.where((e) => e.counter), isEmpty);
    hit(run);
    expect(run.exceptionReady, isFalse);
    grant(run, Upgrade.exceptionHandling);
    expect(
      run.exceptionReady,
      isFalse,
    ); // Rank upgrades do not refresh a catch.
    run.start();
    expect(run.abilities.exceptionCooldown, 0);
    expect(run.abilities.exceptionPause, 0);
    expect(run.exceptionReady, isFalse);
  });

  test('counter kills use normal JIT and ownership rewards without reviving a lethal hit', () {
    final run = prepared()
      ..upgrades[Upgrade.jitCompilation] = 1
      ..upgrades[Upgrade.ownership] = 1
      ..health = 50;
    // Keep the automatic ownership pulse from preempting the catch.
    run.abilities.ownershipTimer = 100;
    run.enemies.addAll([
      TaskEnemy(Vector2(40, 0), health: 1),
      TaskEnemy(Vector2(70, 0), health: 1),
    ]);
    hit(run);
    expect(run.kills, 2);
    expect(run.jitCharge, 6);
    expect(run.health, 42); // 12 damage, then 4 recovered from actual kills.
    final lethal = prepared()..health = 5;
    final survivor = TaskEnemy(Vector2(80, 0), health: 1000);
    lethal.enemies.add(survivor);
    hit(lethal);
    expect(lethal.phase, RunPhase.lost);
    expect(lethal.health, 0);
    expect(lethal.effects.where((e) => e.counter), isEmpty);
    // A base shot fired before the hit may still exist, but no counter landed.
    expect(survivor.health, 1000);
  });

  test(
    'cards preview protection and counter growth without hidden memory costs',
    () {
      final run = RunState()..start();
      final first = run.preview(Upgrade.exceptionHandling);
      expect(first.after.maxHealth, first.before.maxHealth);
      for (final language in ['ja', 'en']) {
        final rows = GameText(language).comparisons(first);
        expect(rows.map((row) => row.values), ['40%', '60', '5.0s', '0.25s']);
        expect(rows.last.cost, isTrue);
      }
      run.upgrades[Upgrade.exceptionHandling] = 1;
      expect(
        const GameText('ja')
            .comparisons(run.preview(Upgrade.exceptionHandling))
            .map((row) => row.values),
        ['40% → 45%', '60 → 82'],
      );
      final base = BuildStats.snapshot({Upgrade.exceptionHandling: 4});
      final optimized = BuildStats.snapshot({
        Upgrade.exceptionHandling: 4,
        Upgrade.compiler: 6,
        Upgrade.spatialIndex: 1,
      });
      expect(base.exceptionReduction, closeTo(0.55, 0.001));
      expect(optimized.counterRadius, greaterThan(base.counterRadius));
      expect(optimized.exceptionCooldown, base.exceptionCooldown);
      expect(optimized.exceptionPause, base.exceptionPause);
    },
  );
}
