import 'package:flame/components.dart';

import 'combat_entities.dart';

/// Interactions come from geometry. No weapon is required to damage a task.
abstract final class CombatRules {
  static double damage(
    TaskEnemy target,
    double amount, {
    Vector2? origin,
    bool area = false,
  }) {
    if (target.type != EnemyType.armoredAllocation || area || origin == null) {
      return amount;
    }
    final incoming = origin - target.position;
    if (incoming.length2 > 0 &&
        incoming.normalized().dot(target.facing) >= 0.25) {
      target.armorFlash = 0.15;
      return amount * 0.55;
    }
    return amount;
  }
}
