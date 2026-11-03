// Run: flutter test tool/generate_social_image.dart
// Original cover artwork built from the game's own character and icon drawings.
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/character_painter.dart';
import 'package:runtime_survivors/game/build.dart';

import '../test/support/runtime_fonts.dart';

const _ink = Color(0xFF243C36);
const _paper = Color(0xFFF4F3EB);
const _mint = Color(0xFF91E2CA);

void label(
  Canvas canvas,
  String value,
  Offset at,
  double size, {
  Color color = _ink,
  FontWeight weight = FontWeight.w400,
  double width = 540,
  double height = 1.2,
  String family = 'Roboto',
}) {
  final text = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: family,
        fontFamilyFallback: const ['RuntimeSansJP'],
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: height,
      ),
    ),
  )..layout(maxWidth: width);
  text.paint(canvas, at);
}

void machine(
  Canvas canvas,
  int kind,
  Offset at,
  double radius, {
  bool player = false,
}) {
  canvas.save();
  canvas.translate(at.dx, at.dy);
  CharacterPainter.draw(
    canvas,
    kind: kind,
    radius: radius,
    player: player,
    time: 1.2,
  );
  canvas.restore();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadRuntimeFonts);
  test('render the original 1200 x 630 social cover', () async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..drawColor(_paper, BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 1200, 8),
      Paint()..color = const Color(0xFFAD4925),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 56, 54, 54),
        const Radius.circular(10),
      ),
      Paint()..color = const Color(0xFFAD4925),
    );
    label(
      canvas,
      '>_',
      const Offset(68, 65),
      30,
      color: _paper,
      weight: FontWeight.w700,
      family: 'RobotoMono',
    );
    label(
      canvas,
      'ROGUELITE × LANGUAGE DESIGN',
      const Offset(128, 76),
      14,
      color: const Color(0xFF58695E),
      weight: FontWeight.w700,
    );
    label(
      canvas,
      'Runtime\nSurvivors',
      const Offset(56, 154),
      78,
      weight: FontWeight.w900,
      height: 0.98,
      width: 560,
    );
    label(
      canvas,
      'タスクを処理し、\n自分だけの言語を設計しよう。',
      const Offset(61, 342),
      24,
      height: 1.65,
      width: 530,
    );
    label(
      canvas,
      'FEATURES ARE YOUR WEAPONS',
      const Offset(62, 446),
      12,
      weight: FontWeight.w700,
      color: const Color(0xFF9A421E),
    );
    final icons = [
      Upgrade.garbageCollection,
      Upgrade.concurrency,
      Upgrade.oop,
      Upgrade.functional,
      Upgrade.asyncStream,
    ];
    for (var i = 0; i < icons.length; i++) {
      final codec = await ui.instantiateImageCodec(
        File('assets/icons/upgrades/${icons[i].name}.png').readAsBytesSync(),
      );
      final image = (await codec.getNextFrame()).image;
      canvas.drawImageRect(
        image,
        const Rect.fromLTWH(0, 0, 256, 256),
        Rect.fromLTWH(60 + i * 62, 474, 48, 48),
        Paint()..filterQuality = FilterQuality.high,
      );
      image.dispose();
      codec.dispose();
    }
    label(
      canvas,
      '5 MIN RUN  /  AUTO ATTACK  /  YOUR OWN BUILD',
      const Offset(62, 563),
      13,
      color: const Color(0xFF58695E),
      weight: FontWeight.w700,
    );

    final arena = RRect.fromRectAndRadius(
      const Rect.fromLTWH(630, 54, 516, 522),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      arena.shift(const Offset(0, 8)),
      Paint()..color = const Color(0x13243C36),
    );
    canvas.save();
    canvas.clipRRect(arena);
    canvas.drawRRect(arena, Paint()..color = const Color(0xFF152425));
    for (double x = 638; x < 1150; x += 40) {
      canvas.drawLine(
        Offset(x, 54),
        Offset(x, 576),
        Paint()..color = const Color(0xFF233334),
      );
    }
    for (double y = 70; y < 580; y += 40) {
      canvas.drawLine(
        Offset(630, y),
        Offset(1146, y),
        Paint()..color = const Color(0xFF233334),
      );
    }
    const player = Offset(885, 316);
    canvas.drawCircle(
      player,
      126,
      Paint()..color = _mint.withValues(alpha: 0.05),
    );
    canvas.drawCircle(
      player,
      126,
      Paint()
        ..color = _mint.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      Rect.fromCircle(center: player, radius: 126),
      -0.8,
      3.2,
      false,
      Paint()
        ..color = _mint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    for (var i = 0; i < 8; i++) {
      final angle = i * pi / 4;
      final p = player + Offset(cos(angle), sin(angle)) * 126;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 5, height: 5),
        Paint()..color = _mint,
      );
    }
    const streamTarget = Offset(1062, 170);
    canvas.drawLine(
      player,
      streamTarget,
      Paint()
        ..color = const Color(0x9977DCF0)
        ..strokeWidth = 2,
    );
    for (var i = 1; i < 7; i++) {
      final p = Offset.lerp(player, streamTarget, i / 7)!;
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 5, height: 5),
        Paint()..color = const Color(0xFF77DCF0),
      );
    }
    for (final p in [
      const Offset(797, 383),
      const Offset(945, 252),
      const Offset(836, 446),
    ]) {
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(pi / 4);
      canvas.drawRect(
        const Rect.fromLTWH(-5, -5, 10, 10),
        Paint()..color = const Color(0xFFE8C974),
      );
      canvas.restore();
    }
    machine(canvas, 0, const Offset(710, 235), 24);
    machine(canvas, 0, const Offset(800, 506), 22);
    machine(canvas, 1, const Offset(780, 134), 23);
    machine(canvas, 2, streamTarget, 32);
    machine(canvas, 4, const Offset(1082, 315), 24);
    for (var i = 0; i < 3; i++) {
      machine(canvas, 11, Offset(999 + i * 33, 410 + i * 35), 22);
    }
    machine(canvas, 14, const Offset(717, 413), 24);
    machine(canvas, 0, player, 37, player: true);
    label(
      canvas,
      'YOUR RUNTIME',
      player + const Offset(-62, 69),
      13,
      color: _mint,
      weight: FontWeight.w700,
      family: 'RobotoMono',
    );
    canvas.restore();
    final picture = recorder.endRecording();
    final image = await picture.toImage(1200, 630);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    await File('web/ogp.png').writeAsBytes(bytes.buffer.asUint8List());
    expect(image.width, 1200);
    expect(image.height, 630);
    image.dispose();
    picture.dispose();
  });
}
