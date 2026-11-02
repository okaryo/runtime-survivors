import 'dart:math';

import 'package:flutter/material.dart';

/// Code-drawn little machines. Silhouettes communicate roles without color.
class CharacterPainter {
  static const colors = [
    Color(0xFFF4A08B),
    Color(0xFFF1D685),
    Color(0xFFC5B1E5),
    Color(0xFFF49AB5),
    Color(0xFF8CC9F2),
    Color(0xFF9ED99C),
    Color(0xFFFFB66E),
    Color(0xFF9CCDE0),
    Color(0xFFB5BBD0),
    Color(0xFFE9A0ED),
    Color(0xFFA6D7CB),
  ];
  static void draw(
    Canvas canvas, {
    required int kind,
    required double radius,
    bool flash = false,
    bool alert = false,
    double time = 0,
    bool player = false,
  }) {
    final color = flash
        ? Colors.white
        : player
        ? const Color(0xFF91E2CA)
        : colors[kind];
    final outline = Paint()
      ..color = const Color(0xFF233D37)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = color;
    final face = Paint()
      ..color = const Color(0xFF233D37)
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    final r = radius;
    final bounce = sin(time * (kind == 1 ? 13 : 6)) * 1.1;
    canvas.save();
    canvas.translate(0, bounce);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0, r + 4), width: r * 1.7, height: 5),
      Paint()..color = const Color(0x55000000),
    );
    if (player) {
      // A tiny chip with a terminal antenna.
      for (final side in [-1.0, 1.0]) {
        for (final y in [-6.0, 2.0, 10.0]) {
          canvas.drawLine(
            Offset(side * r, y),
            Offset(side * (r + 4), y),
            Paint()
              ..color = color
              ..strokeWidth = 2,
          );
        }
      }
      canvas.drawLine(
        Offset(0, -r),
        Offset(0, -r - 7),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        Offset(0, -r - 8),
        3,
        Paint()..color = const Color(0xFFF1D685),
      );
    } else if (kind == 1) {
      // Angular interrupt, with little winglets.
      final body = Path()
        ..moveTo(0, -r - 4)
        ..lineTo(r, -2)
        ..lineTo(r - 2, r)
        ..lineTo(-r + 2, r)
        ..lineTo(-r, -2)
        ..close();
      canvas.drawPath(body, fill);
      canvas.drawPath(body, outline);
      canvas.drawLine(
        Offset(-r - 5, 3),
        Offset(-r - 1, -2),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
      canvas.drawLine(
        Offset(r + 5, 3),
        Offset(r + 1, -2),
        Paint()
          ..color = color
          ..strokeWidth = 3,
      );
    } else if (kind == 9) {
      // A hollow reference, visibly distinct from an ordinary ranged task.
      canvas.drawCircle(Offset.zero, r + 2, fill);
      canvas.drawCircle(Offset.zero, r + 2, outline);
      canvas.drawLine(Offset(-r, r), Offset(r, -r), outline);
      canvas.drawCircle(Offset(0, -r - 5), 3, fill);
    } else if (kind == 10) {
      for (final shift in [5.0, 0.0]) {
        final paper = RRect.fromRectAndRadius(
          Rect.fromLTRB(-r + shift, -r - shift, r + shift, r - shift),
          const Radius.circular(3),
        );
        canvas.drawRRect(paper, fill);
        canvas.drawRRect(paper, outline);
      }
    } else if (kind >= 6) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(-r, -r, r, r),
        Radius.circular(kind == 6 ? 4 : 8),
      );
      canvas.drawRRect(body, fill);
      canvas.drawRRect(body, outline);
      if (kind == 6) {
        for (final side in [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(side * r, -r + 3),
            Offset(side * (r + 6), -r - 3),
            face,
          );
        }
        canvas.drawCircle(Offset(0, r - 4), 2, face);
      } else if (kind == 7) {
        canvas.drawCircle(Offset(0, -r - 5), 5, fill);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -r - 5), radius: 10),
          pi,
          pi,
          false,
          outline,
        );
        canvas.drawLine(Offset(-r - 5, 1), Offset(r + 5, 1), outline);
      } else {
        final shield = Path()
          ..moveTo(0, -r - 8)
          ..lineTo(r + 5, -r)
          ..lineTo(r + 2, r + 5)
          ..lineTo(0, r + 12)
          ..lineTo(-r - 2, r + 5)
          ..lineTo(-r - 5, -r)
          ..close();
        canvas.drawPath(shield, outline);
      }
    } else if (kind == 2) {
      // Allocation is a broad, stacked memory block.
      for (final y in [-5.0, 0.0, 5.0]) {
        final block = RRect.fromRectAndRadius(
          Rect.fromLTWH(-r - 3, -r + y, (r + 3) * 2, r * 1.7),
          const Radius.circular(5),
        );
        canvas.drawRRect(block, fill);
        canvas.drawRRect(block, outline);
      }
    } else if (kind == 4 || kind == 5) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(-r, -r, r, r),
        Radius.circular(kind == 4 ? 3 : 10),
      );
      canvas.drawRRect(body, fill);
      canvas.drawRRect(body, outline);
      if (kind == 4) {
        canvas.drawLine(Offset(0, -r), Offset(0, -r - 10), face);
        canvas.drawCircle(Offset(0, -r - 11), 3, fill);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(0, -r - 9), radius: 7),
          -2.8,
          2.4,
          false,
          outline,
        );
      } else {
        for (final x in [-r - 4, r + 4]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(x, 4), width: 7, height: 11),
              const Radius.circular(2),
            ),
            fill,
          );
          canvas.drawCircle(Offset(x, 3), 1, face);
        }
      }
    } else if (kind == 3) {
      // Deadlock wears two bracket-shaped horns and a lock shackle.
      final shackle = RRect.fromRectAndRadius(
        Rect.fromLTWH(-r * 0.55, -r - 12, r * 1.1, 24),
        const Radius.circular(11),
      );
      canvas.drawRRect(
        shackle,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
      canvas.drawLine(
        Offset(-r, -r + 5),
        Offset(-r - 7, -r - 3),
        Paint()
          ..color = color
          ..strokeWidth = 4,
      );
      canvas.drawLine(
        Offset(r, -r + 5),
        Offset(r + 7, -r - 3),
        Paint()
          ..color = color
          ..strokeWidth = 4,
      );
    }
    if (player || kind == 0 || kind == 3) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(-r, -r, r, r),
        Radius.circular(
          player
              ? 10
              : kind == 3
              ? 7
              : 8,
        ),
      );
      canvas.drawRRect(body, fill);
      canvas.drawRRect(body, outline);
    }
    final eyesY = kind == 2 ? 2.0 : -2.0;
    for (final x in [-r * 0.35, r * 0.35]) {
      if (kind == 2 && !player) {
        canvas.drawLine(Offset(x - 2, eyesY), Offset(x + 2, eyesY), face);
      } else {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(x, eyesY),
            width: 3,
            height: alert ? 6 : 5,
          ),
          face,
        );
      }
    }
    if (alert) {
      canvas.drawOval(const Rect.fromLTWH(-2, 5, 4, 5), face);
    } else {
      canvas.drawArc(
        const Rect.fromLTWH(-4, 1, 8, 7),
        0.2,
        pi - 0.4,
        false,
        face..style = PaintingStyle.stroke,
      );
    }
    // Two little feet keep the shapes distinct from bullets and pickups.
    if (kind != 1 || player) {
      for (final x in [-r * 0.45, r * 0.45]) {
        canvas.drawLine(
          Offset(x, r),
          Offset(x + sin(time * 8 + x) * 2, r + 3),
          Paint()
            ..color = color
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.restore();
  }
}

class CharacterIcon extends CustomPainter {
  CharacterIcon(this.kind);
  final int kind;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2 + 3);
    CharacterPainter.draw(canvas, kind: kind, radius: kind == 3 ? 13 : 12);
  }

  @override
  bool shouldRepaint(CharacterIcon oldDelegate) => oldDelegate.kind != kind;
}
