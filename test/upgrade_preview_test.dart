import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

void main() {
  for (final upgrade in Upgrade.values) {
    test('preview for $upgrade is read-only and matches acquisition', () {
      final run = RunState()..start();
      run.upgrades.addAll({
        Upgrade.garbageCollection: 1,
        Upgrade.concurrency: 2,
        Upgrade.oop: 2,
        Upgrade.functional: 1,
        Upgrade.memory: 1,
        Upgrade.clock: 1,
        Upgrade.cache: 1,
        Upgrade.compiler: 2,
      });
      if (upgrade.isFeature && run.rank(upgrade) == 0) {
        run.upgrades.remove(Upgrade.functional);
      }
      run.health = 37.5;
      run.phase = RunPhase.choosing;
      run.choices = [upgrade];
      final ranks = Map.of(run.upgrades);
      final enemies = run.enemies.toList();
      final cues = run.cues.toSet();
      final prediction = run.preview(upgrade);
      expect(run.upgrades, ranks);
      expect(run.health, 37.5);
      expect(run.phase, RunPhase.choosing);
      expect(run.enemies, enemies);
      expect(run.cues, cues);
      run.choose(upgrade);
      expect(run.health, prediction.afterHealth);
      expect(run.maxHealth, prediction.after.maxHealth);
      expect(run.speed, prediction.after.speed);
      expect(run.pickupRadius, prediction.after.pickupRadius);
      expect(run.attackRange, prediction.after.attackRange);
      expect(run.attackDamage, prediction.after.attackDamage);
      expect(run.attackInterval, prediction.after.attackInterval);
      expect(run.targetCount, prediction.after.targetCount);
      expect(run.gcDamage, prediction.after.gcDamage);
      expect(run.gcRadius, prediction.after.gcRadius);
      expect(run.objectDamage, prediction.after.objectDamage);
      expect(prediction.before.rank(upgrade), ranks[upgrade] ?? 0);
      expect(prediction.beforeHealth, 37.5);
    });
  }

  test('memory previews recovery capped at the new maximum', () {
    final run = RunState()..start();
    run.health = 98;
    final prediction = run.preview(Upgrade.memory);
    expect(prediction.before.maxHealth, 100);
    expect(prediction.after.maxHealth, 125);
    expect(prediction.afterHealth, 125);
    expect(run.health, 98);
    run.health = 35;
    expect(run.preview(Upgrade.memory).afterHealth, 70);
  });

  test('OOP previews HP clamping when memory is reserved', () {
    final run = RunState()..start();
    expect(run.preview(Upgrade.oop).afterHealth, 95);
    run.health = 35;
    final prediction = run.preview(Upgrade.oop);
    expect(prediction.afterHealth, 35);
    expect(prediction.after.maxHealth, 95);
  });
}
