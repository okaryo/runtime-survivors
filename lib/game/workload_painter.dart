import 'dart:math';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart';

import 'ability_runtime.dart';
import 'combat_entities.dart';
import 'workload_hazards.dart';

/// The drawn cells and arc openings match the simulation's collision geometry.
class WorkloadPainter {
  static const leakColor = Color(0xFFF09C67);
  static const timerColor = Color(0xFFB9C9FF);
  static const streamColor = Color(0xFF77DCF0);

  static void leak(Canvas canvas, MemoryLeakPatch patch, double time) {
    final deploying = patch.age < MemoryLeakPatch.armingTime;
    final opacity = (patch.remaining / 1.5).clamp(0.3, 1.0);
    final color = patch.cleaning ? const Color(0xFF819C96) : leakColor;
    final cells = patch.cells.toSet();
    for (var i = 0; i < patch.cells.length; i++) {
      final cell = patch.cells[i];
      final rect = patch.cellRect(cell);
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(
            alpha:
                (patch.cleaning
                    ? 0.06
                    : deploying
                    ? 0.05
                    : 0.22) *
                opacity,
          ),
      );
      canvas.drawRect(
        rect.deflate(0.6),
        Paint()
          ..color = color.withValues(alpha: 0.20 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
      final edges = [
        ((cell.$1, cell.$2 - 1), rect.topLeft, rect.topRight),
        ((cell.$1 + 1, cell.$2), rect.topRight, rect.bottomRight),
        ((cell.$1, cell.$2 + 1), rect.bottomRight, rect.bottomLeft),
        ((cell.$1 - 1, cell.$2), rect.bottomLeft, rect.topLeft),
      ];
      for (final edge in edges.where((e) => !cells.contains(e.$1))) {
        canvas.drawLine(
          edge.$2,
          edge.$3,
          Paint()
            ..color = color.withValues(
              alpha: (deploying ? 0.45 : 0.85) * opacity,
            )
            ..strokeWidth = deploying || patch.cleaning ? 1.2 : 2,
        );
      }
      if (!deploying && !patch.cleaning) {
        // Small allocations remain inside occupied cells; no fake hazard fringe.
        final phase = (time * 1.8 + i * 0.31) % 1;
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + 5 + phase * 8,
            rect.top + 7 + (i % 2) * 5,
            5,
            3,
          ),
          Paint()..color = color.withValues(alpha: 0.65 * opacity),
        );
        if (i % 3 == 0) {
          canvas.drawLine(
            rect.topLeft + const Offset(4, 4),
            rect.topLeft + const Offset(11, 4),
            Paint()
              ..color = color.withValues(alpha: 0.45 * opacity)
              ..strokeWidth = 1,
          );
        }
      }
    }
  }

  static void timerPulse(Canvas canvas, TimerPulse pulse) {
    final opacity = ((TimerPulse.maxRadius - pulse.radius) / 35).clamp(
      0.35,
      1.0,
    );
    final center = Offset(pulse.position.x, pulse.position.y);
    final start = pulse.gapAngle + TimerPulse.gapWidth / 2;
    final sweep = pi * 2 - TimerPulse.gapWidth;
    final rect = Rect.fromCircle(center: center, radius: pulse.radius);
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = timerColor.withValues(alpha: 0.18 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = TimerPulse.width + 6,
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = timerColor.withValues(alpha: 0.88 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = TimerPulse.width,
    );
    // Square brackets identify the two ends and make the escape gap readable.
    for (final angle in [start, start + sweep]) {
      final p = center + Offset(cos(angle), sin(angle)) * pulse.radius;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 7, height: 7),
        Paint()..color = const Color(0xFFF3F5FF).withValues(alpha: opacity),
      );
    }
  }

  static void timerWindup(Canvas canvas, TaskEnemy enemy) {
    final center = Offset(enemy.position.x, enemy.position.y);
    final radius = enemy.radius + 14;
    final gap = atan2(enemy.chargeDirection.y, enemy.chargeDirection.x);
    final progress = 1 - enemy.telegraphRemaining / TimerPulse.windup;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      gap + TimerPulse.gapWidth / 2,
      pi * 2 - TimerPulse.gapWidth,
      false,
      Paint()
        ..color = timerColor.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var i = 0; i < 8; i++) {
      final angle = -pi / 2 + i * pi / 4;
      final p = center + Offset(cos(angle), sin(angle)) * (radius + 6);
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 3, height: 3),
        Paint()
          ..color = timerColor.withValues(alpha: i / 8 <= progress ? 1 : 0.15),
      );
    }
  }

  static void stream(
    Canvas canvas,
    AsyncStreamRuntime stream,
    Vector2 player,
    double time,
  ) {
    final target = stream.target;
    if (target == null || !target.alive) return;
    final from = Offset(player.x, player.y);
    final to = Offset(target.position.x, target.position.y);
    final delta = to - from;
    final length = delta.distance;
    if (length == 0) return;
    final direction = delta / length;
    final preparing = !stream.ready;
    if (preparing) {
      for (double d = 0; d < length; d += 18) {
        canvas.drawLine(
          from + direction * d,
          from + direction * min(length, d + 6),
          Paint()
            ..color = streamColor.withValues(alpha: 0.45)
            ..strokeWidth = 1.5,
        );
      }
      final progress = 1 - stream.preparation / stream.preparationDuration;
      canvas.drawArc(
        Rect.fromCircle(center: from, radius: 25),
        -pi / 2,
        pi * 2 * progress,
        false,
        Paint()
          ..color = streamColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    } else {
      canvas.drawLine(
        from,
        to,
        Paint()
          ..color = streamColor.withValues(
            alpha: stream.flash > 0 ? 0.65 : 0.25,
          )
          ..strokeWidth = stream.flash > 0 ? 3 : 1.5,
      );
      final count = max(1, (length / 36).ceil());
      for (var i = 0; i < count; i++) {
        final fraction = (time * 1.7 + i / count) % 1;
        final p = from + delta * fraction;
        canvas.drawRect(
          Rect.fromCenter(center: p, width: 5, height: 5),
          Paint()..color = streamColor,
        );
      }
    }
    canvas.drawRect(
      Rect.fromCenter(
        center: to,
        width: target.radius * 2 + 10,
        height: target.radius * 2 + 10,
      ),
      Paint()
        ..color = streamColor.withValues(alpha: preparing ? 0.45 : 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }
}
