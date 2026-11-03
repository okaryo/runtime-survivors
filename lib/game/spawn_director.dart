import 'dart:math';

import 'combat_entities.dart';

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
  static const rules = [
    EncounterRule(EnemyType.batch, 30, 0.20, 20, 1),
    EncounterRule(EnemyType.allocation, 40, 0.16, 6, 2),
    EncounterRule(EnemyType.rpc, 50, 0.13, 4, 3),
    EncounterRule(EnemyType.forkBomb, 100, 0.10, 2, 4),
  ];

  int choose(
    double elapsed,
    List<TaskEnemy> enemies,
    Random random, {
    Set<int>? introduced,
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
          budget + rule.cost * rule.batchSize <= 18 &&
          (counts[rule.type] ?? 0) + rule.batchSize <= rule.limit) {
        return rule.type.index;
      }
    }
    final repeatBudget =
        18 - pending.fold(0, (sum, r) => sum + r.cost * r.batchSize);
    final choices = <(int, double)>[(0, 0.48)];
    if (elapsed >= 20) choices.add((1, 0.30));
    for (final rule in rules) {
      if (elapsed >= rule.startsAt &&
          (counts[rule.type] ?? 0) + rule.batchSize <= rule.limit &&
          budget + rule.cost * rule.batchSize <= repeatBudget) {
        choices.add((rule.type.index, rule.weight));
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
