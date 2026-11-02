import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show grant, tick;

RunState prepared() => RunState(random: Random(8))
  ..start()
  ..enemies.clear();
void main() {
  test(
    'Null Safety blocks one projectile, recharges, and never blocks contact',
    () {
      final run = prepared();
      grant(run, Upgrade.nullSafety);
      expect(run.maxHealth, 92);
      expect(run.shieldReady, isTrue);
      run.projectiles.add(
        LinearProjectile(Vector2(-25, 0), Vector2(1000, 0), damage: 11),
      );
      run.update(0.05);
      expect(run.health, 92);
      expect(run.shieldReady, isFalse);
      run.projectiles.add(
        LinearProjectile(Vector2(-25, 0), Vector2(1000, 0), damage: 11),
      );
      run.update(0.05);
      expect(run.health, 81);
      run.pause();
      final remaining = run.shieldTimer;
      tick(run, 10);
      expect(run.shieldTimer, remaining);
      run.resume();
      run.enemies.clear();
      run.invulnerability = 0;
      run.shieldTimer = 0;
      run.enemies.add(TaskEnemy(Vector2.zero(), health: 9999));
      run.update(0.01);
      expect(run.health, 72);
      expect(run.shieldReady, isTrue);
    },
  );
  test('piercing shot hits lined-up tasks once each, without homing or chain recursion', () {
    final run = prepared();
    final a = TaskEnemy(Vector2(100, 0), health: 1000);
    final b = TaskEnemy(Vector2(180, 0), health: 1000);
    final offLine = TaskEnemy(Vector2(180, 100), health: 1000);
    run.enemies.addAll([a, b, offLine]);
    run.projectiles.add(
      LinearProjectile(
        Vector2.zero(),
        Vector2(700, 0),
        damage: 42,
        hostile: false,
        life: 0.4,
      ),
    );
    tick(run, 0.35);
    expect(b.health, 958);
    expect(offLine.health, 1000);
    expect(a.health, greaterThanOrEqualTo(1000 - 42 - run.attackDamage));
    expect(
      run.instructions.where((s) => s.kind == InstructionKind.chain),
      isEmpty,
    );
  });
  test('pipeline affects base interval and bandwidth affects shared projectile speed', () {
    final run = prepared();
    grant(run, Upgrade.pipeline);
    expect(run.attackInterval, closeTo(0.558, 0.0001));
    grant(run, Upgrade.bandwidth);
    expect(run.projectileSpeed, closeTo(736, 0.0001));
    run.upgrades[Upgrade.pipeline] = 100;
    run.upgrades[Upgrade.bandwidth] = 100;
    expect(run.attackInterval, 0.12);
    expect(run.projectileSpeed, 1600);
  });
  test('four feature slots filter new features but preserve invested ones and infrastructure', () {
    final run = prepared();
    for (final feature in [
      Upgrade.garbageCollection,
      Upgrade.concurrency,
      Upgrade.oop,
      Upgrade.functional,
    ]) {
      grant(run, feature);
    }
    expect(run.featureCount, 4);
    for (var i = 0; i < 40; i++) {
      run.phase = RunPhase.running;
      run.xp = 0;
      run.addExperience(run.nextLevelXp);
      expect(run.choices.any((u) => !u.isFeature), isTrue);
      expect(
        run.choices.where((u) => u.isFeature).every((u) => run.rank(u) > 0),
        isTrue,
      );
    }
    run.choices = [Upgrade.nullSafety];
    run.choose(Upgrade.nullSafety);
    expect(run.rank(Upgrade.nullSafety), 0);
  });
}
