import 'dart:math';

import 'package:flame/components.dart';

import 'combat_entities.dart';

class LockBarrier {
  const LockBarrier(this.from, this.to, {required this.warning});
  final Vector2 from;
  final Vector2 to;
  final bool warning;
}

/// Breaking any wait dependency opens the cycle. One side is always an exit.
class DeadlockEncounter {
  DeadlockEncounter(this.core);
  final TaskEnemy core;
  final List<TaskEnemy> nodes = [];
  double warningRemaining = 1.2;
  double exposedRemaining = 0;
  int cycle = 0;
  bool get exposed => exposedRemaining > 0;
  double get damageMultiplier => exposed ? 1 : 0.35;

  List<TaskEnemy> rebuild() {
    nodes.clear();
    warningRemaining = 1.2;
    final radius = core.health < core.maxHealth / 2 ? 175.0 : 145.0;
    for (var i = 0; i < 3; i++) {
      final angle = -pi / 2 + i * 2 * pi / 3 + cycle * pi / 3;
      final offset = Vector2(cos(angle), sin(angle)) * radius;
      nodes.add(
        TaskEnemy(
          core.position + offset,
          kind: EnemyType.lockNode.index,
          owner: core,
          health: 60 + core.maxHealth * 0.025,
        )..formationOffset.setFrom(offset),
      );
    }
    return nodes.toList();
  }

  List<TaskEnemy> advance(double dt, Vector2 player) {
    if (!core.alive) {
      for (final node in nodes) {
        node.health = 0;
      }
      return const [];
    }
    final delta = player - core.position;
    if (delta.length > 160) core.position.add(delta.normalized() * 22 * dt);
    for (final node in nodes.where((n) => n.alive)) {
      node.position.setFrom(core.position + node.formationOffset);
    }
    warningRemaining = max(0, warningRemaining - dt);
    if (exposed) {
      exposedRemaining = max(0, exposedRemaining - dt);
      if (!exposed) {
        cycle++;
        return rebuild();
      }
    }
    return const [];
  }

  void breakDependency() {
    if (exposed || !core.alive) return;
    exposedRemaining = 7;
    for (final node in nodes) {
      node.health = 0;
    }
  }

  Iterable<LockBarrier> get barriers sync* {
    if (!core.alive || exposed || nodes.length != 3) return;
    for (var i = 0; i < 3; i++) {
      if (i == cycle % 3) continue;
      final a = nodes[i];
      final b = nodes[(i + 1) % 3];
      if (a.alive && b.alive) {
        yield LockBarrier(
          a.position,
          b.position,
          warning: warningRemaining > 0,
        );
      }
    }
  }
}
