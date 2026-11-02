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
  test('static pre-checks empower only the first hit and do not change enemy warnings', () {
    final run = RunState(random: Random(2))
      ..start(policy: TypingPolicy.staticTyping)
      ..enemies.clear();
    final target = TaskEnemy(Vector2(250, 0), kind: 4, health: 1000)
      ..attackCooldown = 0;
    run.enemies.add(target);
    run.update(0.01);
    expect(target.checked, isTrue);
    expect(target.telegraphRemaining, closeTo(0.65, 0.0001));
    expect(run.attackDamage, 24);
    run.instructions.clear();
    for (var hit = 0; hit < 2; hit++) {
      run.instructions.add(Instruction(target.position.clone(), target, 10));
      run.update(0.01);
    }
    expect(target.health, 975); // 15 opening damage, then 10.
    expect(target.checked, isFalse);
    tick(run, 0.1);
    expect(target.firstHitConsumed, isTrue);
    final preview = run.preview(Upgrade.compiler);
    expect(
      preview.after.attackInterval,
      closeTo(run.attackInterval * 0.92, 0.0001),
    );
  });
  test('dynamic checks on impact and empower subsequent hits, with optional propagation', () {
    final run = RunState(random: Random(2))
      ..start(policy: TypingPolicy.dynamicTyping)
      ..enemies.clear();
    final target = TaskEnemy(Vector2(250, 0), health: 1000);
    run.enemies.add(target);
    run.update(0.01);
    expect(target.checked, isFalse);
    run.instructions.clear();
    run.instructions.add(Instruction(target.position.clone(), target, 10));
    run.update(0.01);
    expect(target.checked, isTrue);
    expect(target.health, 990);
    run.instructions.add(Instruction(target.position.clone(), target, 10));
    run.update(0.01);
    expect(target.health, 977);
    run.pause();
    final elapsed = run.elapsed;
    tick(run, 2);
    expect(run.elapsed, elapsed);
    run.start(policy: TypingPolicy.dynamicTyping);
    expect(run.policyRank, 1);
    expect(run.policyChoicePending, isFalse);
  });
  test('policy milestones grant a bonus decision without consuming the regular choice or slots', () {
    final run = RunState()..start(policy: TypingPolicy.staticTyping);
    for (final milestone in [5, 10, 15]) {
      run.level = milestone - 1;
      run.addExperience(run.nextLevelXp);
      expect(run.policyChoicePending, isTrue);
      final choices = run.choices.toList();
      run.choose(choices.first);
      expect(run.upgrades, isEmpty);
      final elapsed = run.elapsed;
      tick(run, 2);
      expect(run.elapsed, elapsed);
      run.choosePolicy(PolicyUpgrade.coverage);
      expect(run.policyChoicePending, isFalse);
      expect(run.phase, RunPhase.choosing);
      expect(run.choices, choices);
      run.phase = RunPhase.running;
    }
    expect(run.policyRank, 4);
    expect(run.scanTargets, 8);
    expect(run.featureCount, 0);
    expect(run.infraCount, 0);
    run.start();
    expect(run.policyRank, 1);
  });
  test('dynamic coverage spreads checks and potency increases the shared damage bonus', () {
    final run = RunState()
      ..start(policy: TypingPolicy.dynamicTyping)
      ..enemies.clear();
    run.level = 4;
    run.addExperience(run.nextLevelXp);
    run.choosePolicy(PolicyUpgrade.coverage);
    run.choose(run.choices.first);
    run.upgrades.clear();
    final a = TaskEnemy(Vector2(250, 0), health: 1000);
    final b = TaskEnemy(Vector2(270, 0), health: 1000);
    run.enemies.addAll([a, b]);
    run.instructions.add(Instruction(a.position.clone(), a, 1));
    run.update(0.01);
    expect(a.checked, isTrue);
    expect(b.checked, isTrue);
    run.level = 9;
    run.addExperience(run.nextLevelXp);
    run.choosePolicy(PolicyUpgrade.potency);
    expect(run.policyBonus, closeTo(0.45, 0.0001));
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
