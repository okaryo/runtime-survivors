import 'dart:math';

import 'combat_entities.dart';

enum RushTheme { interrupts, memory, forks, leaks, timers, overload }

extension RushComposition on RushTheme {
  double weight(EnemyType type) => switch (this) {
    RushTheme.interrupts => type == EnemyType.interrupt ? 4 : 1,
    RushTheme.memory =>
      type == EnemyType.allocation || type == EnemyType.rpc ? 6 : 1,
    RushTheme.forks =>
      type == EnemyType.forkBomb || type == EnemyType.batch ? 6 : 1,
    RushTheme.leaks =>
      type == EnemyType.memoryLeak || type == EnemyType.interrupt ? 6 : 1,
    RushTheme.timers =>
      type == EnemyType.timerEvent || type == EnemyType.rpc ? 6 : 1,
    RushTheme.overload => type == EnemyType.request ? 0.5 : 3,
  };
}

class EncounterRule {
  const EncounterRule(
    this.type,
    this.startsAt,
    this.weight,
    this.limit,
    this.cost,
  );
  final EnemyType type;
  final double startsAt;
  final double weight;
  final int limit;
  final int cost;
  int get batchSize => type == EnemyType.batch ? 4 : 1;
}

/// Definitions preserve stable enemy IDs, and share a bounded specialist budget.
class SpawnDirector {
  const SpawnDirector();

  static double healthFor(
    EnemyType type,
    double elapsed, {
    bool reinforced = false,
  }) {
    final base = type == EnemyType.deadlock
        ? 1800 + elapsed * 4
        : (22 + elapsed / 18) *
              switch (type) {
                EnemyType.allocation => 3.0,
                EnemyType.memoryLeak => 3.4,
                EnemyType.timerEvent => 3.2,
                EnemyType.forkBomb => 2.5,
                EnemyType.rpc => 3.6,
                EnemyType.batch => 1.15,
                _ => 1.0,
              };
    final specialistGrowth = type.isSpecialist
        ? 1 + max(0.0, elapsed - 120) / 60
        : 1.0;
    final pressure = switch (pressureStage(elapsed)) {
      2 => 1.45,
      1 => 1.20,
      _ => 1.0,
    };
    return base *
        specialistGrowth *
        pressure *
        (reinforced && type.isSpecialist ? 2.2 : 1);
  }

  static int reinforcedLimit(double elapsed) => elapsed < 150
      ? 0
      : elapsed < 240
      ? 1
      : 2;

  bool shouldReinforce(
    EnemyType type,
    double elapsed,
    List<TaskEnemy> enemies,
    Random random, {
    required bool introduced,
  }) {
    if (!introduced ||
        !type.isSpecialist ||
        enemies.where((e) => e.alive && e.reinforced).length >=
            reinforcedLimit(elapsed)) {
      return false;
    }
    return random.nextDouble() < (elapsed < 240 ? 0.18 : 0.28);
  }

  /// Steady workload grows even between rushes. End pressure stacks on top.
  static double interval(double elapsed, {bool rush = false}) =>
      max(0.20, 0.70 / (1 + max(0.0, elapsed) / 120)) *
      (rush ? 0.55 : 1) *
      switch (pressureStage(elapsed)) {
        2 => 0.42,
        1 => 0.68,
        _ => 1.0,
      };

  static const rules = [
    EncounterRule(EnemyType.batch, 30, 0.20, 20, 1),
    EncounterRule(EnemyType.allocation, 40, 0.16, 6, 2),
    EncounterRule(EnemyType.rpc, 50, 0.13, 4, 3),
    EncounterRule(EnemyType.timerEvent, 65, 0.12, 3, 2),
    EncounterRule(EnemyType.memoryLeak, 90, 0.22, 3, 3),
    EncounterRule(EnemyType.forkBomb, 100, 0.10, 2, 4),
  ];

  static int pressureStage(double elapsed) => elapsed >= 270
      ? 2
      : elapsed >= 240
      ? 1
      : 0;
  static int budgetLimit(double elapsed, {RushTheme? theme}) =>
      18 + pressureStage(elapsed) * 8 + (theme == null ? 0 : 6);
  static int typeLimit(EncounterRule rule, double elapsed) =>
      rule.limit +
      pressureStage(elapsed) * (rule.type == EnemyType.batch ? 4 : 1);

  int choose(
    double elapsed,
    List<TaskEnemy> enemies,
    Random random, {
    Set<int>? introduced,
    RushTheme? theme,
  }) {
    final counts = <EnemyType, int>{};
    for (final enemy in enemies.where((e) => e.alive)) {
      counts.update(enemy.type, (n) => n + 1, ifAbsent: () => 1);
    }
    final budget = rules.fold(
      0,
      (sum, rule) => sum + rule.cost * (counts[rule.type] ?? 0),
    );
    // Reserve one encounter of each new role before spending its budget on repeats.
    final pending =
        introduced == null
              ? <EncounterRule>[]
              : rules.where((r) => !introduced.contains(r.type.index)).toList()
          ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    for (final rule in pending) {
      if (elapsed >= rule.startsAt &&
          budget + rule.cost * rule.batchSize <=
              budgetLimit(elapsed, theme: theme) &&
          (counts[rule.type] ?? 0) + rule.batchSize <=
              typeLimit(rule, elapsed)) {
        return rule.type.index;
      }
    }
    final repeatBudget =
        budgetLimit(elapsed, theme: theme) -
        pending.fold(0, (sum, r) => sum + r.cost * r.batchSize);
    final choices = <(int, double)>[(0, 0.48)];
    if (elapsed >= 20) choices.add((1, 0.30));
    for (final rule in rules) {
      if (elapsed >= rule.startsAt &&
          (counts[rule.type] ?? 0) + rule.batchSize <=
              typeLimit(rule, elapsed) &&
          budget + rule.cost * rule.batchSize <= repeatBudget) {
        choices.add((rule.type.index, rule.weight));
      }
    }
    if (theme != null) {
      for (var i = 0; i < choices.length; i++) {
        final choice = choices[i];
        choices[i] = (
          choice.$1,
          choice.$2 * theme.weight(EnemyType.values[choice.$1]),
        );
      }
    }
    var roll = random.nextDouble() * choices.fold(0.0, (sum, c) => sum + c.$2);
    for (final choice in choices) {
      roll -= choice.$2;
      if (roll <= 0) return choice.$1;
    }
    return 0;
  }
}
