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

  static void recovery(Canvas canvas, RunEffect effect, Vector2 player) {
    const color = Color(0xFFB8FFB2);
    final from = effect.source ?? effect.position;
    final progress = 1 - effect.life / effect.duration;
    for (var i = 0; i < 3; i++) {
      final t = (progress - i * 0.10) / 0.7;
      if (t < 0 || t > 1) continue;
      final position = from + (player - from) * t;
      final p = Offset(position.x, position.y - sin(t * pi) * 14);
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 6, height: 6),
        Paint()..color = color.withValues(alpha: 1 - progress * 0.6),
      );
    }
    final center = Offset(player.x, player.y);
    canvas.drawCircle(
      center,
      22 + progress * 12,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final cross = center + const Offset(24, -22);
    final paint = Paint()
      ..color = color.withValues(alpha: 1 - progress)
      ..strokeWidth = 2;
    canvas.drawLine(
      cross - const Offset(4, 0),
      cross + const Offset(4, 0),
      paint,
    );
    canvas.drawLine(
      cross - const Offset(0, 4),
      cross + const Offset(0, 4),
      paint,
    );
  }

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
    final rect = Rect.fromCircle(center: center, radius: pulse.radius);
    for (final arc in TimerPulse.arcs(pulse.gapAngles)) {
      canvas.drawArc(
        rect,
        arc.$1,
        arc.$2,
        false,
        Paint()
          ..color = timerColor.withValues(alpha: 0.18 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = TimerPulse.width + 6,
      );
      canvas.drawArc(
        rect,
        arc.$1,
        arc.$2,
        false,
        Paint()
          ..color = timerColor.withValues(alpha: 0.88 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = TimerPulse.width,
      );
      for (final angle in [arc.$1, arc.$1 + arc.$2]) {
        final p = center + Offset(cos(angle), sin(angle)) * pulse.radius;
        canvas.drawRect(
          Rect.fromCenter(center: p, width: 7, height: 7),
          Paint()..color = const Color(0xFFF3F5FF).withValues(alpha: opacity),
        );
      }
    }
  }

  static void timerWindup(Canvas canvas, TaskEnemy enemy) {
    final center = Offset(enemy.position.x, enemy.position.y);
    final radius = enemy.radius + 14;
    final progress = 1 - enemy.telegraphRemaining / TimerPulse.windup;
    for (final arc in TimerPulse.arcs(enemy.pulseGaps)) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        arc.$1,
        arc.$2,
        false,
        Paint()
          ..color = timerColor.withValues(alpha: 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
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

  static void collection(Canvas canvas, RunEffect effect) {
    final p = Offset(effect.position.x, effect.position.y);
    final progress = 1 - effect.life / effect.duration;
    const color = Color(0xFF91E2CA);
    canvas.drawCircle(
      p,
      effect.radius,
      Paint()..color = color.withValues(alpha: (1 - progress) * 0.18),
    );
    canvas.drawCircle(
      p,
      effect.radius,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawArc(
      Rect.fromCircle(center: p, radius: effect.radius * (1 - progress * 0.8)),
      progress * pi * 3,
      pi * 1.6,
      false,
      Paint()
        ..color = color.withValues(alpha: (1 - progress) * 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (var i = 0; i < 12; i++) {
      final angle = i * pi / 6;
      final at =
          p + Offset(cos(angle), sin(angle)) * effect.radius * (1 - progress);
      canvas.drawRect(
        Rect.fromCenter(center: at, width: 6, height: 6),
        Paint()..color = color.withValues(alpha: 1 - progress),
      );
    }
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: 'GC',
        style: TextStyle(
          color: color.withValues(alpha: 1 - progress),
          fontSize: 16,
          fontFamily: 'RobotoMono',
          fontWeight: FontWeight.bold,
        ),
      ),
    )..layout();
    text.paint(canvas, p - Offset(text.width / 2, effect.radius + 24));
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
