// Run: dart run tool/preview_victory_fanfare.dart /tmp/runtime-victory.wav
// Offline approximation of the Web Audio triangle voices and gain envelope.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:runtime_survivors/audio/victory_fanfare.dart';

void main(List<String> arguments) {
  const rate = 44100;
  final duration = victoryFanfare
      .map((tone) => tone.offset + tone.duration)
      .reduce(max);
  final count = ((duration + 0.05) * rate).ceil();
  final wav = ByteData(44 + count * 2);
  void tag(int offset, String text) => wav.buffer.asUint8List().setRange(
    offset,
    offset + text.length,
    text.codeUnits,
  );
  tag(0, 'RIFF');
  wav.setUint32(4, wav.lengthInBytes - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, 1, Endian.little);
  wav.setUint32(24, rate, Endian.little);
  wav.setUint32(28, rate * 2, Endian.little);
  wav.setUint16(32, 2, Endian.little);
  wav.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  wav.setUint32(40, count * 2, Endian.little);
  for (var i = 0; i < count; i++) {
    var sample = 0.0;
    for (final tone in victoryFanfare) {
      final t = i / rate - tone.offset;
      if (t < 0 || t >= tone.duration) continue;
      final release = max(0.005, tone.hold);
      final gain = t < 0.005
          ? 0.0001 * pow(1600, t / 0.005)
          : t <= release
          ? 0.16
          : 0.16 *
                pow(0.0001 / 0.16, (t - release) / (tone.duration - release));
      sample += 2 / pi * asin(sin(2 * pi * tone.frequency * t)) * gain;
    }
    wav.setInt16(
      44 + i * 2,
      (sample.clamp(-1, 1) * 32767).round(),
      Endian.little,
    );
  }
  final output = arguments.isEmpty
      ? '/tmp/runtime-victory.wav'
      : arguments.first;
  File(output).writeAsBytesSync(wav.buffer.asUint8List());
  stdout.writeln('Wrote $output (${duration.toStringAsFixed(2)} seconds)');
}
