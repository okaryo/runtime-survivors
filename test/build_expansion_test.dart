import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';

import 'run_state_test.dart' show grant, tick;

RunState prepared() => RunState(random: Random(8))
  ..start()
  ..enemies.clear();
void main() {
  test('retired abilities are excluded and shared infrastructure is available initially', () {
    final run = prepared();
    expect(run.canUpgrade(Upgrade.nullSafety), isFalse);
    expect(run.canUpgrade(Upgrade.coprocessor), isFalse);
    expect(run.canUpgrade(Upgrade.spatialIndex), isTrue);
    expect(run.canUpgrade(Upgrade.compiler), isTrue);
  });
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
  test('compiler affects base interval and bandwidth affects shared projectile speed', () {
    final run = prepared();
    grant(run, Upgrade.compiler);
    expect(run.attackInterval, closeTo(0.5704, 0.0001));
    grant(run, Upgrade.bandwidth);
    expect(run.projectileSpeed, closeTo(736, 0.0001));
    run.upgrades[Upgrade.compiler] = 100;
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
