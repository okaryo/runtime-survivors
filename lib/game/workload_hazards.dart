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
  static const lifetime = 12.0;
  static const armingTime = 0.55;
  static const cleanupTime = 1.25;
  static const limit = 20;
  static const perSourceLimit = 6;
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
  TimerPulse(this.position, List<double> gaps)
    : gapAngles = List.unmodifiable(
        gaps.map((a) => a % (pi * 2)).toList()..sort(),
      );

  static List<double> randomGaps(Random random) {
    final first = random.nextDouble() * pi * 2;
    final separation = gapWidth + 0.6;
    return [
      first,
      first + separation + random.nextDouble() * (pi * 2 - separation * 2),
    ];
  }

  static Iterable<(double, double)> arcs(List<double> gaps) sync* {
    final angles = gaps.map((a) => a % (pi * 2)).toList()..sort();
    for (var i = 0; i < angles.length; i++) {
      final start = angles[i] + gapWidth / 2;
      final end =
          angles[(i + 1) % angles.length] -
          gapWidth / 2 +
          (i == angles.length - 1 ? pi * 2 : 0);
      if (end > start) yield (start, end - start);
    }
  }

  static const speed = 145.0;
  static const maxRadius = 320.0;
  static const width = 8.0;
  static const gapWidth = pi / 3;
  static const damage = 12.0;
  static const limit = 8;
  static const windup = 1.0;
  static const cooldown = 4.4;
  final Vector2 position;
  final List<double> gapAngles;
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
    final insideGap = gapAngles.any(
      (gap) => atan2(sin(angle - gap), cos(angle - gap)).abs() < gapWidth / 2,
    );
    if (!insideGap) return true;
    // Rounded arc tips have the same collision width as their drawn endpoints.
    for (final gap in gapAngles) {
      for (final edge in [gap - gapWidth / 2, gap + gapWidth / 2]) {
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
    }
    return false;
  }
}
