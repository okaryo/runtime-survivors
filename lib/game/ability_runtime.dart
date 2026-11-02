import 'dart:math';

import 'package:flame/components.dart';

import 'combat_entities.dart';

class SlowField {
  SlowField(
    this.position,
    this.radius,
    this.multiplier, {
    this.remaining = 3.5,
  });
  final Vector2 position;
  final double radius;
  final double multiplier;
  double remaining;
}

/// A shot snapshot, not another attack generator: echoes cannot record echoes.
class PendingEcho {
  PendingEcho(this.target, this.damage, this.jumps, {this.remaining = 0.65});
  final TaskEnemy target;
  final double damage;
  final int jumps;
  double remaining;
}

/// Per-run state for abilities; never stored in catalog definitions or previews.
class AbilityRuntime {
  final List<SlowField> fields = [];
  final List<PendingEcho> echoes = [];
  TaskEnemy? focusTarget;
  int focusStacks = 0;
  double focusIdle = 0;
  double fieldTimer = 0;
  double healingTimer = 0;
  double _healingSpent = 0;

  void reset() {
    fields.clear();
    echoes.clear();
    focusTarget = null;
    focusStacks = 0;
    focusIdle = 0;
    fieldTimer = 0;
    healingTimer = 0;
    _healingSpent = 0;
  }

  void advance(double dt) {
    fieldTimer -= dt;
    focusIdle -= dt;
    healingTimer -= dt;
    if (focusIdle <= 0 || focusTarget?.alive == false) {
      focusTarget = null;
      focusStacks = 0;
    }
    for (final field in fields) {
      field.remaining -= dt;
    }
    fields.removeWhere((f) => f.remaining <= 0);
    for (final echo in echoes) {
      echo.remaining -= dt;
    }
  }

  double focusMultiplier(TaskEnemy target, double perStack) {
    focusStacks = identical(focusTarget, target) ? min(6, focusStacks + 1) : 0;
    focusTarget = target;
    focusIdle = 2;
    return 1 + perStack * focusStacks;
  }

  double claimHealing(double amount, double cap) {
    if (healingTimer <= 0) {
      healingTimer = 1;
      _healingSpent = 0;
    }
    final granted = min(amount, max(0.0, cap - _healingSpent));
    _healingSpent += granted;
    return granted;
  }
}
