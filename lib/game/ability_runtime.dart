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
}

/// Per-run state for abilities; never stored in catalog definitions or previews.
class AbilityRuntime {
  static const jitDecay = 9.0;
  static const jitKillGain = 9.0;
  final List<SlowField> fields = [];
  final stream = AsyncStreamRuntime();
  // A signature includes both the operation and its visible input variant.
  final Set<int> cachedInputs = {};
  double jitCharge = 0;
  double fieldTimer = 0;
  double memoTimer = 0;
  double ownershipTimer = 0;
  double gcPause = 0;
  double healingTimer = 0;
  double _healingSpent = 0;

  void reset() {
    fields.clear();
    stream.reset();
    cachedInputs.clear();
    jitCharge = 0;
    fieldTimer = memoTimer = ownershipTimer = gcPause = 0;
    healingTimer = 0;
    _healingSpent = 0;
  }

  void advance(double dt) {
    jitCharge = max(0, jitCharge - jitDecay * dt);
    fieldTimer -= dt;
    memoTimer -= dt;
    ownershipTimer -= dt;
    gcPause = max(0, gcPause - dt);
    healingTimer -= dt;
    for (final field in fields) {
      field.remaining -= dt;
      field.arming -= dt;
    }
    fields.removeWhere((f) => f.remaining <= 0);
  }

  void recordKill({
    bool summoned = false,
    bool node = false,
    bool boss = false,
  }) {
    jitCharge = min(
      100,
      jitCharge +
          (boss
              ? 30
              : summoned
              ? 2
              : node
              ? 4
              : jitKillGain),
    );
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
