import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

import 'run_state_test.dart' show tick;

RunState prepared() => RunState(random: Random(70))
  ..start()
  ..spawnRadius = 10000
  ..enemies.clear()
  ..upgrades[Upgrade.asyncStream] = 1;

// Discard in-flight base shots to isolate channel damage, retaining base firing.
void channelTime(RunState run, double seconds) {
  for (var frame = 0; frame < (seconds * 60).ceil(); frame++) {
    run.instructions.clear();
    for (final enemy in run.enemies.where(
      (e) => e.position.distanceTo(run.player) < 500,
    )) {
      enemy.position.setValues(200 + enemy.inputVariant * 30, 0);
    }
    run.update(1 / 60);
  }
}

void main() {
  test(
    'ranks two and four add distinct independently prepared connections',
    () {
      final run = prepared()..upgrades[Upgrade.asyncStream] = 2;
      final targets = List.generate(
        3,
        (i) => TaskEnemy(
          Vector2(200 + i * 30.0, 0),
          inputVariant: i,
          health: 1000,
        ),
      );
      run.enemies.addAll(targets);
      channelTime(run, 0.32);
      expect(run.abilities.streams.length, 2);
      expect(run.abilities.streams.map((c) => c.target).toSet().length, 2);
      expect(targets.where((e) => e.health < 1000).length, 2);
      run.upgrades[Upgrade.asyncStream] = 3;
      run.update(0.01);
      expect(run.abilities.streams.length, 2);
      run.upgrades[Upgrade.asyncStream] = 4;
      run.update(0.01);
      expect(run.abilities.streams.length, 3);
      expect(run.abilities.streams.map((c) => c.target).toSet().length, 3);
      expect(run.abilities.streams.last.ready, isFalse);
      channelTime(run, 0.22);
      expect(run.abilities.streams.every((c) => c.ready), isTrue);
      expect(targets.every((e) => e.health < 1000), isTrue);
      run.start();
      expect(run.abilities.streams.length, 1);
      expect(run.abilities.streams.first.target, isNull);
    },
  );
  test('stream prepares, then deals repeated independent hits while movement and base fire continue', () {
    final run = prepared();
    final target = TaskEnemy(Vector2(200, 0), health: 1000);
    run.enemies.add(target);
    channelTime(run, 0.20);
    expect(run.abilities.streams.first.target, same(target));
    expect(run.abilities.streams.first.ready, isFalse);
    expect(target.health, 1000);
    channelTime(run, 0.13);
    expect(run.abilities.streams.first.ready, isTrue);
    expect(target.health, 986);
    channelTime(run, 0.26);
    expect(target.health, 972);
    final beforeMovement = target.health;
    run.movement.setValues(0, 1);
    tick(run, 0.3);
    expect(run.player.y, greaterThan(0));
    expect(run.attackInterval, 0.62);
    expect(target.health, lessThanOrEqualTo(beforeMovement - run.attackDamage));
  });

  test('a subscription stays on its target and pays setup again after completion or range loss', () {
    final run = prepared();
    final target = TaskEnemy(Vector2(200, 0), health: 1000);
    final closer = TaskEnemy(Vector2(150, 0), health: 1000);
    run.enemies.add(target);
    run.update(0.01);
    run.enemies.add(closer);
    run.update(0.01);
    expect(run.abilities.streams.first.target, same(target));
    target.health = 0;
    run.update(0.01);
    expect(run.abilities.streams.first.target, same(closer));
    expect(run.abilities.streams.first.preparation, closeTo(0.30, 0.001));
    closer.position.setValues(1000, 0);
    run.update(0.01);
    expect(run.abilities.streams.first.target, isNull);
    closer.position.setValues(200, 0);
    run.update(0.01);
    expect(run.abilities.streams.first.preparation, closeTo(0.30, 0.001));
  });

  test('stream setup and active ticks freeze during pause and choices, and restart clears the subscription', () {
    final run = prepared();
    run.enemies.add(TaskEnemy(Vector2(200, 0), health: 1000));
    channelTime(run, 0.1);
    run.pause();
    final remaining = run.abilities.streams.first.preparation;
    tick(run, 3);
    expect(run.abilities.streams.first.preparation, remaining);
    run.resume();
    channelTime(run, 0.6);
    final health = run.enemies.first.health;
    final tickTimer = run.abilities.streams.first.tickTimer;
    run.addExperience(run.nextLevelXp);
    tick(run, 2);
    expect(run.enemies.first.health, health);
    expect(run.abilities.streams.first.tickTimer, tickTimer);
    run.start();
    expect(run.abilities.streams.first.target, isNull);
    expect(run.abilities.streams.first.preparation, 0);
  });

  test('compiler and spatial expansion support the stream; cards expose setup and later improvements', () {
    final base = BuildStats.snapshot({Upgrade.asyncStream: 1});
    final faster = BuildStats.snapshot({
      Upgrade.asyncStream: 1,
      Upgrade.compiler: 1,
    });
    expect(faster.streamInterval, closeTo(base.streamInterval * 0.92, 0.0001));
    expect(
      faster.streamPreparation,
      closeTo(base.streamPreparation * 0.92, 0.0001),
    );
    final run = RunState()..start();
    for (final language in ['ja', 'en']) {
      final text = GameText(language);
      final first = text.comparisons(run.preview(Upgrade.asyncStream));
      expect(first.map((c) => c.values), ['14', '1', '0.30s']);
      expect(first.last.cost, isTrue);
    }
    run.upgrades[Upgrade.asyncStream] = 1;
    final next = const GameText('ja')
        .comparisons(run.preview(Upgrade.asyncStream));
    expect(next.map((c) => c.values), ['14 → 18', '1 → 2', '0.30s → 0.26s']);
    run.upgrades[Upgrade.spatialIndex] = 1;
    run.enemies.clear();
    final target = TaskEnemy(Vector2(290, 0), health: 1000);
    run.enemies.add(target);
    run.update(0.01);
    expect(run.abilities.streams.first.target, same(target));
  });
}
