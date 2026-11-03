import 'dart:math';

import 'package:flame/components.dart';

import 'combat_entities.dart';

class LockBarrier {
  const LockBarrier(this.from, this.to, {required this.warning});
  final Vector2 from;
  final Vector2 to;
  final bool warning;
}

/// Durable dependencies form a forward barricade between player and core.
class DeadlockEncounter {
  DeadlockEncounter(this.core);
  final TaskEnemy core;
  final List<TaskEnemy> nodes = [];
  double warningRemaining = 1.4;
  double exposedRemaining = 0;
  int cycle = 0;
  bool get exposed => exposedRemaining > 0;
  double get damageMultiplier => exposed ? 1 : 0.15;

  List<TaskEnemy> rebuild(Vector2 player) {
    nodes.clear();
    warningRemaining = 1.4;
    final delta = player - core.position;
    final forward = delta.length2 > 0 ? delta.normalized() : Vector2(0, 1);
    final side = Vector2(-forward.y, forward.x);
    final depth = min(170.0, delta.length * (cycle.isEven ? 0.55 : 0.65));
    final spread = core.health < core.maxHealth / 2 ? 160.0 : 130.0;
    for (var i = 0; i < 3; i++) {
      final offset = forward * depth + side * ((i - 1) * spread);
      nodes.add(
        TaskEnemy(
          core.position + offset,
          kind: EnemyType.lockNode.index,
          owner: core,
          health: 140 + core.maxHealth * 0.055,
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
    if (delta.length2 > 0) {
      core.position.add(
        delta.normalized() *
            min(delta.length, 40 * core.movementMultiplier * dt),
      );
    }
    for (final node in nodes.where((n) => n.alive)) {
      node.position.setFrom(core.position + node.formationOffset);
    }
    warningRemaining = max(0, warningRemaining - dt);
    if (exposed) {
      exposedRemaining = max(0, exposedRemaining - dt);
      if (!exposed) {
        cycle++;
        return rebuild(player);
      }
    }
    return const [];
  }

  void breakDependency() {
    if (exposed || !core.alive) return;
    exposedRemaining = 5.5;
    for (final node in nodes) {
      node.health = 0;
    }
  }

  Iterable<LockBarrier> get barriers sync* {
    if (!core.alive || exposed || nodes.length != 3) return;
    for (var i = 0; i < 2; i++) {
      yield LockBarrier(
        nodes[i].position,
        nodes[i + 1].position,
        warning: warningRemaining > 0,
      );
    }
    for (final i in [0, 2]) {
      yield LockBarrier(
        core.position,
        nodes[i].position,
        warning: warningRemaining > 0,
      );
    }
  }
}
