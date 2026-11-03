import 'dart:math';

import 'package:flame/components.dart';

import 'combat_entities.dart';

/// One subscription is retained until its target finishes or leaves range.
class AsyncStreamRuntime {
  TaskEnemy? target;
  double preparation = 0;
  double preparationDuration = 0;
  double tickTimer = 0;
  double flash = 0;
  bool get ready => target != null && preparation <= 0;

  void connect(TaskEnemy task, double duration) {
    target = task;
    preparation = preparationDuration = duration;
    tickTimer = flash = 0;
  }

  void reset() {
    target = null;
    preparation = preparationDuration = tickTimer = flash = 0;
  }
}

/// Deferred work stays at its placement point until a task needs processing.
class SlowField {
  SlowField(this.position, this.radius, this.multiplier, {this.damage = 68});
  final Vector2 position;
  final double radius;
  final double multiplier;
  final double damage;
  double remaining = 7;
  double arming = 0.35;
  bool triggered = false;
  static const activeDuration = 2.4;
  static const tickInterval = 0.6;
  double tickTimer = tickInterval;
  double flash = 0;
}

/// Per-run state for abilities; never stored in catalog definitions or previews.
class AbilityRuntime {
  static const jitDecay = 9.0;
  final List<SlowField> fields = [];
  final streams = [AsyncStreamRuntime()];
  double jitCharge = 0;
  double fieldTimer = 0;
  double exceptionCooldown = 0;
  double exceptionPause = 0;
  double ownershipTimer = 0;
  double gcPause = 0;
  double healingTimer = 0;
  double _healingSpent = 0;

  void reset() {
    fields.clear();
    streams
      ..clear()
      ..add(AsyncStreamRuntime());
    jitCharge = 0;
    fieldTimer = ownershipTimer = gcPause = 0;
    exceptionCooldown = exceptionPause = 0;
    healingTimer = 0;
    _healingSpent = 0;
  }

  void advance(double dt) {
    jitCharge = max(0, jitCharge - jitDecay * dt);
    fieldTimer -= dt;
    exceptionCooldown = max(0, exceptionCooldown - dt);
    exceptionPause = max(0, exceptionPause - dt);
    ownershipTimer -= dt;
    gcPause = max(0, gcPause - dt);
    healingTimer -= dt;
    for (final field in fields) {
      field.remaining -= dt;
      field.arming -= dt;
      field.flash = max(0, field.flash - dt);
      if (field.triggered) field.tickTimer -= dt;
    }
    fields.removeWhere((f) => f.remaining <= 0);
  }

  void recordKill(TaskEnemy enemy) =>
      jitCharge = min(100, jitCharge + enemy.jitGain);

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
