import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/game/language_profile.dart';

import 'run_state_test.dart' show tick;

void main() {
  test('Ownership contributes a Rust affinity while hybrid profiles follow invested weights', () {
    expect(
      LanguageProfile.analyze(TypingPolicy.staticTyping, {
        Upgrade.ownership: 2,
        Upgrade.nullSafety: 1,
      }).language,
      'Rust',
    );
    expect(
      LanguageProfile.analyze(TypingPolicy.dynamicTyping, {
        Upgrade.oop: 4,
        Upgrade.functional: 1,
        Upgrade.concurrency: 1,
      }).language,
      'Ruby',
    );
    expect(
      LanguageProfile.analyze(TypingPolicy.dynamicTyping, {
        Upgrade.oop: 2,
        Upgrade.functional: 4,
        Upgrade.concurrency: 2,
      }).language,
      'JavaScript',
    );
  });
  test('static policy extends enemy warnings and applies only the advertised damage cost', () {
    final run = RunState(random: Random(2))
      ..start(policy: TypingPolicy.staticTyping)
      ..enemies.clear();
    final rpc = TaskEnemy(Vector2(200, 0), kind: 4, health: 9999)
      ..attackCooldown = 0;
    run.enemies.add(rpc);
    run.update(0.01);
    expect(rpc.telegraphRemaining, closeTo(1.35, 0.0001));
    expect(run.attackDamage, closeTo(21.6, 0.0001));
    expect(run.gcDamage, BuildStats.snapshot({}).gcDamage);
    expect(run.objectDamage, 16);
    final preview = run.preview(Upgrade.compiler);
    expect(preview.before.attackDamage, closeTo(21.6, 0.0001));
    expect(preview.after.attackDamage, closeTo(27, 0.0001));
  });
  test('dynamic policy boosts on enemy type switches, obeys cooldown, and freezes when paused', () {
    final run = RunState(random: Random(2))
      ..start(policy: TypingPolicy.dynamicTyping)
      ..enemies.clear();
    final first = TaskEnemy(Vector2(80, 0), health: 99999);
    run.enemies.add(first);
    run.update(0.01);
    expect(run.dynamicBoostActive, isFalse);
    first.position.x = 290;
    final second = TaskEnemy(Vector2(80, 0), kind: 1, health: 99999);
    run.enemies.add(second);
    tick(run, 0.65);
    expect(run.dynamicBoostActive, isTrue);
    expect(run.attackInterval, closeTo(0.62 / 1.3, 0.0001));
    final preview = run.preview(Upgrade.pipeline);
    expect(preview.before.attackInterval, run.attackInterval);
    expect(
      preview.after.attackInterval,
      closeTo(run.attackInterval * 0.9, 0.0001),
    );
    final timer = run.dynamicTimer;
    run.pause();
    tick(run, 5);
    expect(run.dynamicTimer, timer);
    run.resume();
    run.enemies.clear();
    tick(run, 3.1);
    expect(run.dynamicBoostActive, isFalse);
    expect(run.dynamicCooldown, greaterThan(0));
    run.start(policy: TypingPolicy.staticTyping);
    expect(run.dynamicCooldown, 0);
    expect(run.dynamicBoostActive, isFalse);
  });
  test('language profiles depend on policy and invested ranks, not combat damage or outcome', () {
    final go = {
      Upgrade.garbageCollection: 1,
      Upgrade.concurrency: 2,
      Upgrade.oop: 1,
    };
    expect(
      LanguageProfile.analyze(TypingPolicy.staticTyping, go).language,
      'Go',
    );
    final java = {...go, Upgrade.oop: 3};
    expect(
      LanguageProfile.analyze(TypingPolicy.staticTyping, java).language,
      'Java',
    );
    expect(
      LanguageProfile.analyze(TypingPolicy.dynamicTyping, go).language,
      'Python',
    );
    expect(
      LanguageProfile.analyze(TypingPolicy.dynamicTyping, {
        Upgrade.functional: 3,
        Upgrade.concurrency: 1,
      }).language,
      'JavaScript',
    );
    expect(
      LanguageProfile.analyze(TypingPolicy.staticTyping, {}).language,
      'custom',
    );
    final profile = LanguageProfile.analyze(TypingPolicy.staticTyping, java);
    java[Upgrade.oop] = 0;
    expect(profile.language, 'Java');
    expect(profile.dominantFeatures.first, Upgrade.oop);
    expect(profile.investments[Upgrade.oop], 3);
  });
}
