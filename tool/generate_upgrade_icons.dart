// Run: flutter test tool/generate_upgrade_icons.dart
// Original vector artwork, rasterized at 4x for use at 28–48 logical pixels.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runtime_survivors/game/run_state.dart';

const _ink = Color(0xFF243C36);
const _paper = Color(0xFFFFFCF3);

class _Artwork {
  _Artwork(this.canvas, this.feature);
  final Canvas canvas;
  final bool feature;
  Color get accent =>
      feature ? const Color(0xFFAD4925) : const Color(0xFF286258);
  Color get light =>
      feature ? const Color(0xFFF6BB79) : const Color(0xFF91D8BF);

  void path(List<Offset> points, {Color color = _ink, double width = 3}) {
    final p = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      p.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void line(double x1, double y1, double x2, double y2, {Color color = _ink}) =>
      path([Offset(x1, y1), Offset(x2, y2)], color: color);

  void box(
    double x,
    double y,
    double w,
    double h, {
    Color? fill,
    double r = 3,
  }) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(r),
    );
    canvas.drawRRect(rect, Paint()..color = fill ?? _paper);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void dot(double x, double y, double r, {Color? fill}) {
    canvas.drawCircle(Offset(x, y), r, Paint()..color = fill ?? light);
    canvas.drawCircle(
      Offset(x, y),
      r,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void polygon(List<Offset> points, {Color? fill}) {
    final p = Path()..addPolygon(points, true);
    canvas.drawPath(p, Paint()..color = fill ?? light);
    canvas.drawPath(
      p,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 2.5,
    );
  }

  void arrow(double x, double y, double endX, double endY) {
    line(x, y, endX, endY, color: accent);
    path([
      Offset(endX - 5, endY - 4),
      Offset(endX, endY),
      Offset(endX - 5, endY + 4),
    ], color: accent);
  }

  void draw(Upgrade upgrade) {
    box(
      3,
      3,
      58,
      58,
      fill: feature ? const Color(0xFFFFE3BB) : const Color(0xFFD5EDE0),
      r: 13,
    );
    switch (upgrade) {
      case Upgrade.garbageCollection:
        box(17, 23, 29, 29, fill: _paper, r: 4);
        box(14, 18, 35, 7, fill: light, r: 2);
        box(25, 12, 13, 6, fill: light, r: 2);
        // A circular sweep on the collection bin.
        final arc = Path()
          ..moveTo(38, 34)
          ..cubicTo(28, 25, 20, 40, 30, 44)
          ..cubicTo(35, 46, 40, 42, 40, 38);
        canvas.drawPath(
          arc,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        path([
          const Offset(33, 34),
          const Offset(38, 34),
          const Offset(38, 29),
        ], color: accent);
        line(48, 35, 53, 30, color: accent);
        line(48, 44, 54, 44, color: accent);
      case Upgrade.concurrency:
        // One input splits into three concurrent lanes.
        line(13, 32, 24, 32);
        path([
          const Offset(27, 17),
          const Offset(24, 17),
          const Offset(24, 47),
          const Offset(27, 47),
        ]);
        arrow(25, 17, 49, 17);
        arrow(25, 32, 49, 32);
        arrow(25, 47, 49, 47);
        dot(13, 32, 4, fill: _paper);
      case Upgrade.oop:
        // Three independently working objects share a parent.
        line(32, 23, 20, 40);
        line(32, 23, 44, 40);
        box(23, 12, 18, 16, fill: light);
        box(10, 38, 19, 16, fill: _paper);
        box(35, 38, 19, 16, fill: _paper);
        dot(28, 19, 1, fill: _ink);
        dot(35, 19, 1, fill: _ink);
        line(16, 46, 22, 46, color: accent);
        line(41, 46, 47, 46, color: accent);
      case Upgrade.functional:
        // Lambda, with a chain of composed stages.
        path(
          [
            const Offset(24, 12),
            const Offset(29, 12),
            const Offset(42, 35),
            const Offset(47, 35),
          ],
          color: accent,
          width: 4,
        );
        path(
          [const Offset(32, 19), const Offset(21, 35)],
          color: accent,
          width: 4,
        );
        line(13, 48, 51, 48, color: accent);
        dot(13, 48, 5, fill: _paper);
        dot(32, 48, 5);
        dot(51, 48, 5, fill: _paper);
      case Upgrade.memory:
        // RAM module, recognizable even at sidebar size.
        box(10, 19, 44, 28, fill: light);
        for (final x in [17.0, 28.0, 39.0]) {
          box(x, 26, 8, 12, fill: _paper, r: 1);
        }
        for (final x in [16.0, 24.0, 32.0, 40.0, 48.0]) {
          line(x, 47, x, 52, color: accent);
        }
        line(13, 16, 23, 16, color: accent);
      case Upgrade.clock:
        dot(32, 34, 20, fill: _paper);
        box(25, 8, 14, 6, fill: light, r: 2);
        line(32, 34, 32, 22, color: accent);
        line(32, 34, 43, 29, color: accent);
        for (final p in [
          const Offset(32, 17),
          const Offset(49, 34),
          const Offset(32, 51),
          const Offset(15, 34),
        ]) {
          canvas.drawCircle(p, 1.5, Paint()..color = _ink);
        }
        dot(32, 34, 2, fill: accent);
      case Upgrade.cache:
        // Layered cache with a fast-access flash.
        for (final y in [39.0, 29.0, 19.0]) {
          polygon([
            Offset(10, y + 6),
            Offset(32, y - 3),
            Offset(54, y + 6),
            Offset(32, y + 15),
          ], fill: y == 19 ? light : _paper);
        }
        polygon([
          const Offset(34, 10),
          const Offset(25, 26),
          const Offset(33, 26),
          const Offset(29, 39),
          const Offset(42, 22),
          const Offset(34, 22),
        ], fill: const Color(0xFFF6BB79));
      case Upgrade.nullSafety:
        polygon([
          const Offset(15, 14),
          const Offset(49, 14),
          const Offset(46, 39),
          const Offset(32, 54),
          const Offset(18, 39),
        ], fill: light);
        path(
          [const Offset(24, 31), const Offset(30, 37), const Offset(41, 24)],
          color: accent,
          width: 4,
        );
      case Upgrade.patternMatching:
        for (final x in [14.0, 30.0, 46.0]) {
          box(x, 17, 7, 30, fill: light, r: 2);
        }
        arrow(9, 32, 56, 32);
      case Upgrade.pipeline:
        for (final y in [17.0, 32.0, 47.0]) {
          arrow(12, y, 51, y);
        }
        line(26, 11, 26, 53);
        line(39, 11, 39, 53);
      case Upgrade.bandwidth:
        for (final y in [19.0, 32.0, 45.0]) {
          path([
            Offset(13, y - 5),
            Offset(21, y),
            Offset(13, y + 5),
          ], color: accent);
          path([
            Offset(29, y - 5),
            Offset(37, y),
            Offset(29, y + 5),
          ], color: accent);
        }
        line(50, 14, 50, 50);
      case Upgrade.lazyEvaluation:
        dot(32, 32, 20, fill: _paper);
        line(25, 23, 25, 41, color: accent);
        line(39, 23, 39, 41, color: accent);
        line(17, 52, 47, 52, color: accent);
      case Upgrade.memoization:
        box(12, 12, 31, 31, fill: light);
        box(21, 21, 31, 31, fill: _paper);
        path([
          const Offset(30, 33),
          const Offset(42, 33),
          const Offset(42, 43),
          const Offset(32, 43),
        ], color: accent);
        path([
          const Offset(36, 39),
          const Offset(32, 43),
          const Offset(36, 47),
        ], color: accent);
      case Upgrade.jitCompilation:
        path([const Offset(12, 48), const Offset(12, 17)], color: accent);
        path([const Offset(12, 48), const Offset(51, 48)], color: accent);
        path(
          [
            const Offset(19, 39),
            const Offset(29, 35),
            const Offset(37, 24),
            const Offset(49, 15),
          ],
          color: accent,
          width: 4,
        );
        path([
          const Offset(40, 15),
          const Offset(49, 15),
          const Offset(49, 24),
        ], color: accent);
      case Upgrade.ownership:
        dot(24, 30, 12, fill: light);
        path(
          [
            const Offset(35, 30),
            const Offset(52, 30),
            const Offset(52, 39),
            const Offset(46, 39),
            const Offset(46, 34),
          ],
          color: accent,
          width: 4,
        );
        line(20, 30, 25, 30);
      case Upgrade.spatialIndex:
        for (final x in [15.0, 32.0, 49.0]) {
          line(x, 13, x, 51);
          line(13, x, 51, x);
        }
        dot(32, 32, 12, fill: light);
      case Upgrade.coprocessor:
        box(10, 18, 20, 28, fill: light);
        box(34, 18, 20, 28, fill: _paper);
        line(30, 26, 34, 26, color: accent);
        line(30, 38, 34, 38, color: accent);
        for (final x in [15.0, 24.0, 39.0, 48.0]) {
          line(x, 12, x, 18);
          line(x, 46, x, 52);
        }
      case Upgrade.memoryProtection:
        polygon([
          const Offset(13, 13),
          const Offset(51, 13),
          const Offset(47, 40),
          const Offset(32, 54),
          const Offset(17, 40),
        ], fill: light);
        line(32, 23, 32, 41, color: accent);
        line(23, 32, 41, 32, color: accent);
      case Upgrade.asyncStream:
        // A subscription feeds a single lane of event packets into one receiver.
        box(9, 24, 10, 16, fill: _paper, r: 2);
        line(19, 32, 46, 32, color: accent);
        for (final x in [23.0, 32.0, 41.0]) {
          box(x, 29, 5, 6, fill: light, r: 0);
        }
        box(47, 21, 9, 22, fill: light, r: 2);
        path([
          const Offset(17, 18),
          const Offset(21, 13),
          const Offset(42, 13),
          const Offset(46, 18),
        ], color: accent);
        line(23, 47, 41, 47, color: accent);
      case Upgrade.compiler:
        // Code passes through an optimizing funnel, producing one bright result.
        path([
          const Offset(20, 13),
          const Offset(13, 20),
          const Offset(20, 27),
        ], color: accent);
        path([
          const Offset(44, 13),
          const Offset(51, 20),
          const Offset(44, 27),
        ], color: accent);
        line(34, 12, 29, 28, color: accent);
        polygon([
          const Offset(14, 33),
          const Offset(50, 33),
          const Offset(36, 44),
          const Offset(36, 51),
          const Offset(28, 55),
          const Offset(28, 44),
        ], fill: light);
        line(10, 46, 16, 46, color: accent);
        line(48, 46, 54, 46, color: accent);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('render original upgrade icon assets', () async {
    final directory = Directory('assets/icons/upgrades')
      ..createSync(recursive: true);
    final sheet = ui.PictureRecorder();
    final sheetCanvas = Canvas(sheet)
      ..drawColor(const Color(0xFFF4F3EB), BlendMode.src);
    for (final upgrade in Upgrade.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(4);
      _Artwork(canvas, upgrade.isFeature).draw(upgrade);
      final picture = recorder.endRecording();
      final image = await picture.toImage(256, 256);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('${directory.path}/${upgrade.name}.png')
          .writeAsBytesSync(bytes.buffer.asUint8List());
      final index = upgrade.index;
      sheetCanvas.drawImage(
        image,
        Offset(20 + (index % 4) * 276.0, 20 + (index ~/ 4) * 276.0),
        Paint(),
      );
      image.dispose();
      picture.dispose();
    }
    final picture = sheet.endRecording();
    final image = await picture.toImage(
      1124,
      20 + ((Upgrade.values.length + 3) ~/ 4) * 276,
    );
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    File('/tmp/runtime-upgrade-icons.png')
        .writeAsBytesSync(bytes.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
}
