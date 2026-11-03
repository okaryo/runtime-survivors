import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'run_state.dart';
import 'character_painter.dart';
import 'workload_painter.dart';
import '../audio/sound_cue.dart';
import '../l10n/game_text.dart';

class RuntimeGame extends FlameGame with KeyboardEvents {
  RuntimeGame(this.run);
  final RunState run;
  void Function(SoundCue)? onSound;
  void Function(RunPhase)? onPhaseChanged;
  RunPhase? _notifiedPhase;
  GameText text = const GameText('ja');
  bool inputBlocked = false;
  void Function(Iterable<String>)? onDiscover;
  final revision = ValueNotifier(0);
  double _uiTimer = 0;
  static const mint = Color(0xFF91E2CA);
  static const coral = Color(0xFFF28D77);

  void flushSounds() {
    for (final cue in run.cues.toSet()) {
      onSound?.call(cue);
    }
    run.cues.clear();
  }

  void refresh() {
    if (_notifiedPhase != run.phase) {
      _notifiedPhase = run.phase;
      onPhaseChanged?.call(run.phase);
    }
    onDiscover?.call([
      for (final kind in run.seenEnemies) 'enemy.$kind',
      for (final upgrade in run.seenUpgrades) 'upgrade.${upgrade.name}',
    ]);
    flushSounds();
    revision.value++;
  }

  @override
  Color backgroundColor() => const Color(0xFF152425);

  @override
  void update(double dt) {
    super.update(dt);
    final before = run.phase;
    run.spawnRadius = sqrt(size.x * size.x + size.y * size.y) / 2 + 65;
    run.update(dt);
    flushSounds();
    _uiTimer += dt;
    if ((_uiTimer >= 0.1 && run.phase == RunPhase.running) ||
        before != run.phase) {
      _uiTimer = 0;
      refresh();
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (inputBlocked) {
      run.movement.setZero();
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape ||
          event.logicalKey == LogicalKeyboardKey.keyP) {
        if (run.phase == RunPhase.running) {
          run.pause();
        } else {
          run.resume();
        }
        refresh();
        return KeyEventResult.handled;
      }
      if (run.phase == RunPhase.choosing) {
        final index = [
          LogicalKeyboardKey.digit1,
          LogicalKeyboardKey.digit2,
          LogicalKeyboardKey.digit3,
        ].indexOf(event.logicalKey);
        if (index >= 0 && index < run.choices.length) {
          run.choose(run.choices[index]);
          refresh();
          return KeyEventResult.handled;
        }
      }
    }
    final movementKeys = {
      LogicalKeyboardKey.keyH,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyL,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    };
    if (run.phase == RunPhase.running) {
      double axis(
        LogicalKeyboardKey a,
        LogicalKeyboardKey b,
        LogicalKeyboardKey c,
      ) =>
          keysPressed.contains(a) ||
              keysPressed.contains(b) ||
              keysPressed.contains(c)
          ? 1
          : 0;
      run.movement.setValues(
        axis(
              LogicalKeyboardKey.keyD,
              LogicalKeyboardKey.arrowRight,
              LogicalKeyboardKey.keyL,
            ) -
            axis(
              LogicalKeyboardKey.keyA,
              LogicalKeyboardKey.arrowLeft,
              LogicalKeyboardKey.keyH,
            ),
        axis(
              LogicalKeyboardKey.keyS,
              LogicalKeyboardKey.arrowDown,
              LogicalKeyboardKey.keyJ,
            ) -
            axis(
              LogicalKeyboardKey.keyW,
              LogicalKeyboardKey.arrowUp,
              LogicalKeyboardKey.keyK,
            ),
      );
    } else {
      run.movement.setZero();
    }
    return movementKeys.contains(event.logicalKey)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    canvas.clipRect(Offset.zero & size.toSize());
    final center = Offset(size.x / 2, size.y / 2);
    final origin = center - Offset(run.player.x, run.player.y);
    final grid = Paint()
      ..color = const Color(0xFF233334)
      ..strokeWidth = 1;
    for (double x = origin.dx % 48; x < size.x; x += 48) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), grid);
    }
    for (double y = origin.dy % 48; y < size.y; y += 48) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), grid);
    }
    for (double x = origin.dx % 240; x < size.x; x += 240) {
      for (double y = origin.dy % 240; y < size.y; y += 240) {
        canvas.drawLine(
          Offset(x - 4, y),
          Offset(x + 4, y),
          Paint()..color = const Color(0xFF48605C),
        );
        canvas.drawLine(
          Offset(x, y - 4),
          Offset(x, y + 4),
          Paint()..color = const Color(0xFF48605C),
        );
      }
    }
    if (run.pressureStage > 0) {
      canvas.drawRect(
        Offset.zero & size.toSize(),
        Paint()
          ..color = coral.withValues(
            alpha: run.pressureStage == 2 ? 0.045 : 0.02,
          ),
      );
      canvas.drawRect(
        const Offset(2, 2) & Size(size.x - 4, size.y - 4),
        Paint()
          ..color = coral.withValues(alpha: run.pressureStage == 2 ? 0.7 : 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    Offset point(Vector2 v) => Offset(v.x, v.y);
    for (final patch in run.leakPatches) {
      WorkloadPainter.leak(canvas, patch, run.elapsed);
    }
    for (final pulse in run.timerPulses) {
      WorkloadPainter.timerPulse(canvas, pulse);
    }
    for (final field in run.abilities.fields) {
      final p = point(field.position);
      canvas.drawCircle(
        p,
        field.radius,
        Paint()
          ..color = const Color(0xFFB6A9EF).withValues(
            alpha: min(field.flash > 0 ? 0.18 : 0.08, field.remaining * 0.06),
          ),
      );
      canvas.drawCircle(
        p,
        field.radius,
        Paint()
          ..color = const Color(0xFFB6A9EF)
              .withValues(alpha: min(0.6, field.remaining * 0.3))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (field.triggered) {
        canvas.drawArc(
          Rect.fromCircle(center: p, radius: field.radius * 0.82),
          run.elapsed * 2,
          pi * 1.4,
          false,
          Paint()
            ..color = const Color(0xFFB6A9EF)
                .withValues(alpha: min(0.55, field.remaining * 0.4))
            ..style = PaintingStyle.stroke
            ..strokeWidth = field.flash > 0 ? 3 : 1.5,
        );
      }
      _text(
        canvas,
        field.triggered ? '!' : '...',
        p - const Offset(9, 10),
        const Color(0xFFB6A9EF),
        18,
        bold: true,
      );
    }
    for (final hazard in run.hazards) {
      final p = point(hazard.position);
      final progress = (1 - hazard.remaining / hazard.duration).clamp(0.0, 1.0);
      canvas.drawCircle(
        p,
        hazard.radius,
        Paint()..color = coral.withValues(alpha: 0.12),
      );
      canvas.drawCircle(
        p,
        hazard.radius,
        Paint()
          ..color = coral
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawArc(
        Rect.fromCircle(center: p, radius: hazard.radius),
        -pi / 2,
        progress * pi * 2,
        false,
        Paint()
          ..color = const Color(0xFFFFD59C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        p - const Offset(7, 7),
        p + const Offset(7, 7),
        Paint()
          ..color = coral
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        p - const Offset(7, -7),
        p + const Offset(7, -7),
        Paint()
          ..color = coral
          ..strokeWidth = 2,
      );
    }
    for (final barrier in run.lockBarriers) {
      final paint = Paint()
        ..color = (barrier.warning ? const Color(0xFFFFD36D) : coral)
            .withValues(alpha: barrier.warning ? 0.55 : 0.9)
        ..strokeWidth = barrier.warning ? 2 : 6
        ..strokeCap = StrokeCap.round;
      final a = point(barrier.from), b = point(barrier.to);
      if (barrier.warning) {
        final length = (b - a).distance;
        if (length > 0) {
          final direction = (b - a) / length;
          for (double d = 0; d < length; d += 18) {
            canvas.drawLine(
              a + direction * d,
              a + direction * min(length, d + 9),
              paint,
            );
          }
        }
      } else {
        canvas.drawLine(a, b, paint);
      }
    }
    for (final enemy in run.enemies.where(
      (e) => e.type == EnemyType.batch && e.owner?.alive == true,
    )) {
      canvas.drawLine(
        point(enemy.position),
        point(enemy.owner!.position),
        Paint()
          ..color = const Color(0xFFC5B1E5).withValues(alpha: 0.25)
          ..strokeWidth = 1,
      );
    }
    for (final enemy in run.enemies.where(
      (e) => e.kind >= 4 && e.telegraphRemaining > 0,
    )) {
      final p = point(enemy.position);
      if (enemy.type == EnemyType.timerEvent) {
        WorkloadPainter.timerWindup(canvas, enemy);
      } else if (enemy.type == EnemyType.rpc) {
        canvas.drawCircle(
          p,
          enemy.radius + 6 + sin(run.elapsed * 18) * 2,
          Paint()
            ..color = coral.withValues(alpha: 0.65)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawCircle(
          p,
          42 + sin(run.elapsed * 12) * 4,
          Paint()
            ..color = const Color(0xFF9ED99C)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    for (final shot in run.projectiles) {
      final p = point(shot.position);
      final paint = Paint()
        ..color = shot.hostile ? coral : const Color(0xFF9DDBFF)
        ..strokeWidth = shot.hostile ? 3 : 7
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        p - point(shot.velocity.normalized() * (shot.hostile ? 10 : 26)),
        p,
        paint,
      );
      if (shot.hostile) {
        canvas.drawCircle(
          p,
          shot.radius,
          Paint()
            ..color = coral
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    for (final object in run.objects) {
      final p = point(object.position);
      canvas.drawCircle(
        p,
        16,
        Paint()..color = const Color(0xFFE8C974).withValues(alpha: 0.12),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 22, height: 22),
          const Radius.circular(5),
        ),
        Paint()..color = const Color(0xFFE8C974),
      );
      _text(
        canvas,
        '{}',
        p - const Offset(7, 7),
        const Color(0xFF152425),
        12,
        bold: true,
      );
    }
    for (final gem in run.experience) {
      canvas.save();
      canvas.translate(gem.position.x, gem.position.y);
      canvas.rotate(pi / 4);
      canvas.drawRect(
        const Rect.fromLTWH(-4, -4, 8, 8),
        Paint()..color = const Color(0xFFE8C974),
      );
      canvas.restore();
    }
    for (final effect in run.effects) {
      if (effect.recoveredMemory > 0) {
        WorkloadPainter.recovery(canvas, effect, run.player);
        continue;
      }
      if (effect.counter) {
        WorkloadPainter.counter(canvas, effect);
        _text(
          canvas,
          'CATCH',
          point(effect.position) + const Offset(-22, -75),
          const Color(0xFFFFC46B),
          13,
          bold: true,
        );
        continue;
      }
      if (effect.collection) {
        WorkloadPainter.collection(canvas, effect);
        continue;
      }
      final progress = 1 - effect.life / effect.duration;
      canvas.drawCircle(
        point(effect.position),
        effect.radius * (effect.pulse ? progress : 0.3 + progress),
        Paint()
          ..color =
              (effect.optimized
                      ? const Color(0xFFFFD36D)
                      : effect.healing
                      ? const Color(0xFFA9F0A9)
                      : effect.pulse
                      ? mint
                      : coral)
                  .withValues(alpha: (1 - progress) * 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = effect.pulse ? 3 : 1.5,
      );
    }
    for (final enemy in run.enemies) {
      final color = enemy.flash > 0
          ? const Color(0xFFFFFFFF)
          : switch (enemy.kind) {
              1 => const Color(0xFFE8C974),
              2 => const Color(0xFFB9A0DC),
              3 => const Color(0xFFF294BB),
              _ => coral,
            };
      canvas.save();
      canvas.translate(enemy.position.x, enemy.position.y);
      canvas.save();
      if (enemy.reinforced) canvas.scale(1.25);
      CharacterPainter.draw(
        canvas,
        kind: enemy.kind,
        radius: enemy.baseRadius,
        flash: enemy.flash > 0,
        alert: enemy.telegraphRemaining > 0,
        time: run.elapsed + enemy.position.x * 0.01,
      );
      canvas.restore();
      if (enemy.reinforced) {
        const heavyColor = Color(0xFFFFD27A);
        for (final gap in [3.0, 7.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCircle(center: Offset.zero, radius: enemy.radius + gap),
              const Radius.circular(6),
            ),
            Paint()
              ..color = heavyColor.withValues(alpha: gap == 3 ? 0.9 : 0.55)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        final bar = Rect.fromLTWH(-22, -enemy.radius - 29, 44, 4);
        canvas.drawRect(bar, Paint()..color = const Color(0xFF31423F));
        canvas.drawRect(
          Rect.fromLTWH(
            bar.left,
            bar.top,
            bar.width * (enemy.health / enemy.maxHealth).clamp(0, 1),
            bar.height,
          ),
          Paint()..color = heavyColor,
        );
        _text(
          canvas,
          text('reinforced'),
          Offset(text.isJapanese ? -14 : -26, -enemy.radius - 45),
          heavyColor,
          9,
          bold: true,
        );
      }
      if (enemy.type == EnemyType.rpc) {
        _text(
          canvas,
          enemy.retryCount == 0 ? 'SEND' : 'RETRY ${enemy.retryCount}',
          Offset(-20, -enemy.radius - 18),
          const Color(0xFF8CC9F2),
          9,
        );
      }
      if (enemy.kind == 3) {
        canvas.drawRect(
          Rect.fromLTWH(-25, -37, 50, 4),
          Paint()..color = const Color(0xFF31423F),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            -25,
            -37,
            50 * (enemy.health / enemy.maxHealth).clamp(0, 1),
            4,
          ),
          Paint()..color = color,
        );
      }
      if (enemy.type == EnemyType.lockNode) {
        canvas.drawRect(
          const Rect.fromLTWH(-16, -27, 32, 4),
          Paint()..color = const Color(0xFF31423F),
        );
        canvas.drawRect(
          Rect.fromLTWH(
            -16,
            -27,
            32 * (enemy.health / enemy.maxHealth).clamp(0, 1),
            4,
          ),
          Paint()..color = const Color(0xFFF3CD84),
        );
      }
      canvas.restore();
    }
    for (final channel in run.abilities.streams) {
      WorkloadPainter.stream(canvas, channel, run.player, run.elapsed);
    }
    for (final shot in run.instructions) {
      final shotColor = switch (shot.kind) {
        InstructionKind.base =>
          run.jitCharge >= 50 ? const Color(0xFFFFD36D) : mint,
        InstructionKind.object => const Color(0xFFE8C974),
        InstructionKind.chain => const Color(0xFFCCA7F5),
      };
      final direction = shot.target.position - shot.position;
      final tail = direction.length2 == 0
          ? Vector2.zero()
          : direction.normalized() * 13;
      canvas.drawLine(
        point(shot.position - tail),
        point(shot.position),
        Paint()
          ..color = shotColor
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        point(shot.position),
        3,
        Paint()..color = const Color(0xFFF1FFF9),
      );
    }
    final position = point(run.player);
    if (run.recoveredMemory > 0) {
      _text(
        canvas,
        run.recoveryLabel,
        position + const Offset(-25, -50),
        const Color(0xFFB8FFB2),
        13,
        bold: true,
      );
    }
    if (run.rank(Upgrade.jitCompilation) > 0) {
      final rect = Rect.fromLTWH(position.dx - 30, position.dy + 47, 60, 5);
      canvas.drawRect(rect, Paint()..color = const Color(0xFF4D4835));
      canvas.drawRect(
        Rect.fromLTWH(rect.left, rect.top, rect.width * run.jitCharge / 100, 5),
        Paint()..color = const Color(0xFFFFD36D),
      );
      _text(
        canvas,
        'JIT ${run.jitCharge.round()}%',
        position + const Offset(-27, 56),
        const Color(0xFFFFD36D),
        10,
      );
    }
    if (run.rank(Upgrade.exceptionHandling) > 0) {
      WorkloadPainter.exceptionGuard(canvas, run.player, run.exceptionReady);
    }
    if (run.rank(Upgrade.garbageCollection) > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: position, radius: 28),
        -pi / 2,
        pi * 2 * run.gcProgress,
        false,
        Paint()
          ..color = mint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }

    canvas.drawCircle(
      position,
      32,
      Paint()..color = mint.withValues(alpha: 0.04),
    );
    canvas.drawCircle(
      position,
      23,
      Paint()..color = mint.withValues(alpha: 0.08),
    );
    if (run.rank(Upgrade.garbageCollection) > 0) {
      canvas.drawCircle(
        position,
        run.gcRadius,
        Paint()
          ..color = mint.withValues(alpha: 0.12)
          ..style = PaintingStyle.stroke,
      );
    }
    canvas.save();
    canvas.translate(position.dx, position.dy);
    CharacterPainter.draw(
      canvas,
      kind: 0,
      radius: 16,
      player: true,
      flash: run.invulnerability > 0,
      time: run.elapsed,
    );
    canvas.restore();
    _text(
      canvas,
      'YOU',
      position + const Offset(-10, 31),
      mint.withValues(alpha: 0.9),
      11,
    );
    canvas.restore();
    canvas.restore();
  }

  void _text(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size, {
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontFamily: 'RobotoMono',
          fontFamilyFallback: const ['RuntimeSansJP', 'Roboto'],
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }
}
