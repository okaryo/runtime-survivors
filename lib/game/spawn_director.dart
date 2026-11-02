import 'dart:math';

import 'combat_entities.dart';

/// Specialists spend more of the encounter budget than pursuing tasks.
class SpawnDirector {
  const SpawnDirector();
  int choose(double elapsed, List<TaskEnemy> enemies, Random random) {
    final ranged = enemies.where((e) => e.alive && e.kind == 4).length;
    final summoners = enemies.where((e) => e.alive && e.kind == 5).length;
    final budget = ranged * 3 + summoners * 5;
    final roll = random.nextDouble();
    if (elapsed >= 110 && summoners < 2 && budget <= 12 && roll < 0.10) {
      return 5;
    }
    if (elapsed >= 40 && ranged < 4 && budget <= 14 && roll < 0.24) return 4;
    if (elapsed >= 45 && roll < 0.42) return 2;
    if (elapsed >= 20 && roll < 0.68) return 1;
    return 0;
  }
}
