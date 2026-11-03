import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flame/components.dart';

import 'combat_entities.dart';

/// Leaked allocations occupy grid cells, including their actual collision shape.
class MemoryLeakPatch {
  MemoryLeakPatch(Vector2 position, this.source, {int pattern = 0})
    : position = Vector2(
        (position.x / cellSize).round() * cellSize,
        (position.y / cellSize).round() * cellSize,
      ),
      cells = layouts[pattern % layouts.length];

  static const cellSize = 22.0;
  static const lifetime = 8.0;
  static const armingTime = 0.55;
  static const cleanupTime = 1.25;
  static const limit = 12;
  static const perSourceLimit = 3;
  static const damage = 8.0;
  static const layouts = <List<(int, int)>>[
    [
      (-2, -1),
      (-1, -1),
      (0, -1),
      (-1, 0),
      (0, 0),
      (1, 0),
      (2, 0),
      (-1, 1),
      (0, 1),
      (1, 1),
      (0, 2),
      (1, 2),
    ],
    [
      (-1, -2),
      (0, -2),
      (-1, -1),
      (0, -1),
      (1, -1),
      (-2, 0),
      (-1, 0),
      (0, 0),
      (1, 0),
      (2, 0),
      (-2, 1),
      (1, 1),
    ],
    [
      (-2, -2),
      (-1, -2),
      (-1, -1),
      (0, -1),
      (-1, 0),
      (0, 0),
      (1, 0),
      (0, 1),
      (1, 1),
      (2, 1),
      (1, 2),
      (2, 2),
    ],
  ];

  final Vector2 position;
  final TaskEnemy source;
  final List<(int, int)> cells;
  double remaining = lifetime;
  double age = 0;
  bool cleaning = false;
  bool get active => !cleaning && age >= armingTime && remaining > 0;

  Rect cellRect((int, int) cell) => Rect.fromLTWH(
    position.x + cell.$1 * cellSize - cellSize / 2,
    position.y + cell.$2 * cellSize - cellSize / 2,
    cellSize,
    cellSize,
  );

  bool touches(Vector2 point, double radius) => cells.any((cell) {
    final rect = cellRect(cell);
    final dx = point.x - point.x.clamp(rect.left, rect.right);
    final dy = point.y - point.y.clamp(rect.top, rect.bottom);
    return dx * dx + dy * dy <= radius * radius;
  });

  void advance(double dt, {required bool sourcePresent}) {
    age += dt;
    remaining -= dt;
    if (!source.alive || !sourcePresent) {
      cleaning = true;
      remaining = min(remaining, cleanupTime);
    }
  }
}

/// A moving arc has an open sector; only the ring, not its interior, hurts.
class TimerPulse {
  TimerPulse(this.position, this.gapAngle);

  static const speed = 145.0;
  static const maxRadius = 320.0;
  static const width = 8.0;
  static const gapWidth = pi / 2.5;
  static const damage = 12.0;
  static const limit = 8;
  static const windup = 1.0;
  static const cooldown = 4.4;
  final Vector2 position;
  final double gapAngle;
  double radius = 24;
  double previousRadius = 24;

  void advance(double dt) {
    previousRadius = radius;
    radius = min(maxRadius, radius + speed * dt);
  }

  bool touches(Vector2 point, double actorRadius) {
    final delta = point - position;
    final distance = delta.length;
    final margin = actorRadius + width / 2;
    if (distance < previousRadius - margin || distance > radius + margin) {
      return false;
    }
    final angle = atan2(delta.y, delta.x);
    final difference = atan2(
      sin(angle - gapAngle),
      cos(angle - gapAngle),
    ).abs();
    if (difference >= gapWidth / 2) return true;
    // Rounded arc tips have the same collision width as their drawn endpoints.
    for (final edge in [gapAngle - gapWidth / 2, gapAngle + gapWidth / 2]) {
      final direction = Vector2(cos(edge), sin(edge));
      if (crossesCircle(
        position + direction * previousRadius,
        position + direction * radius,
        point,
        margin,
      )) {
        return true;
      }
    }
    return false;
  }
}
