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
  double _heading = 0;
  double _depth = 0;
  double _spread = 130;
  static const turnSpeed = 0.6;
  bool get exposed => exposedRemaining > 0;
  double get damageMultiplier => exposed ? 1 : 0.15;

  List<TaskEnemy> rebuild(Vector2 player) {
    nodes.clear();
    warningRemaining = 1.4;
    final delta = player - core.position;
    _heading = delta.length2 > 0 ? atan2(delta.y, delta.x) : pi / 2;
    final forward = Vector2(cos(_heading), sin(_heading));
    final side = Vector2(-forward.y, forward.x);
    _depth = min(170.0, delta.length * (cycle.isEven ? 0.55 : 0.65));
    _spread = core.health < core.maxHealth / 2 ? 160.0 : 130.0;
    for (var i = 0; i < 3; i++) {
      final offset = forward * _depth + side * ((i - 1) * _spread);
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
    if (!exposed && nodes.length == 3) {
      final toward = player - core.position;
      if (toward.length2 > 0) {
        final difference = atan2(
          sin(atan2(toward.y, toward.x) - _heading),
          cos(atan2(toward.y, toward.x) - _heading),
        );
        _heading += difference.clamp(-turnSpeed * dt, turnSpeed * dt);
      }
      final depth = min(170.0, toward.length * (cycle.isEven ? 0.55 : 0.65));
      _depth += (depth - _depth).clamp(-60 * dt, 60 * dt);
      final forward = Vector2(cos(_heading), sin(_heading));
      final side = Vector2(-forward.y, forward.x);
      for (var i = 0; i < nodes.length; i++) {
        final node = nodes[i];
        if (!node.alive) continue;
        node.formationOffset.setFrom(
          forward * _depth + side * ((i - 1) * _spread),
        );
        node.position.setFrom(core.position + node.formationOffset);
      }
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
