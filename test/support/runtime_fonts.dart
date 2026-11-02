import 'dart:io';

import 'package:flutter/services.dart';

/// Measure PC card text with Flutter's bundled UI font rather than Ahem's
/// square test glyphs, which greatly overestimate the width of English prose.
Future<void> loadRuntimeFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) throw StateError('Run these tests with flutter test.');
  final loader = FontLoader('Roboto');
  for (final weight in ['Regular', 'Bold']) {
    loader.addFont(
      File('$root/bin/cache/artifacts/material_fonts/Roboto-$weight.ttf')
          .readAsBytes()
          .then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await loader.load();
}
