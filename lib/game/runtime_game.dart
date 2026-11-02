import 'dart:math';

import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'run_state.dart';
import '../audio/sound_cue.dart';
import '../l10n/game_text.dart';

class RuntimeGame extends FlameGame with KeyboardEvents {
  RuntimeGame(this.run);
  final RunState run;
  void Function(SoundCue)? onSound;
  GameText text = const GameText('ja');
  bool inputBlocked = false;
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
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    Offset point(Vector2 v) => Offset(v.x, v.y);
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
      final progress = 1 - effect.life / 0.5;
      canvas.drawCircle(
        point(effect.position),
        effect.radius * (effect.pulse ? progress : 0.3 + progress),
        Paint()
          ..color = (effect.pulse ? mint : coral).withValues(
            alpha: (1 - progress) * 0.7,
          )
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
              _ => coral,
            };
      canvas.save();
      canvas.translate(enemy.position.x, enemy.position.y);
      if (enemy.kind == 1) canvas.rotate(pi / 4);
      final box = RRect.fromRectAndRadius(
        Rect.fromCircle(center: Offset.zero, radius: enemy.radius),
        const Radius.circular(3),
      );
      canvas.drawRRect(box, Paint()..color = color.withValues(alpha: 0.12));
      canvas.drawRRect(
        box,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      canvas.drawLine(
        const Offset(-4, -3),
        const Offset(4, -3),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.drawLine(
        const Offset(-4, 3),
        const Offset(1, 3),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.restore();
    }
    for (final shot in run.instructions) {
      final direction = shot.target.position - shot.position;
      final tail = direction.length2 == 0
          ? Vector2.zero()
          : direction.normalized() * 13;
      canvas.drawLine(
        point(shot.position - tail),
        point(shot.position),
        Paint()
          ..color = mint
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
    final playerColor = run.invulnerability > 0 ? coral : mint;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: position, width: 30, height: 30),
        const Radius.circular(9),
      ),
      Paint()..color = playerColor,
    );
    _text(
      canvas,
      '<>',
      position - const Offset(10, 9),
      const Color(0xFF152425),
      15,
      bold: true,
    );
    _text(
      canvas,
      'YOU',
      position + const Offset(-10, 29),
      mint.withValues(alpha: 0.65),
      9,
    );
    canvas.restore();
    _text(
      canvas,
      '${text('heap')} / SECTOR ${((run.player.x + 10000) / 240).floor()}.${((run.player.y + 10000) / 240).floor()}',
      const Offset(20, 18),
      const Color(0xFF77918B),
      10,
    );
    _text(
      canvas,
      text('legend'),
      Offset(20, size.y - 30),
      const Color(0xFF77918B),
      10,
    );
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
          fontFamily: 'monospace',
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }
}
