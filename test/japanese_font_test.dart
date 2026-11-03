import 'dart:io';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Japanese and monospace fonts are registered as separate families',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
      for (final entry in {
        'RuntimeSansJP': 'assets/fonts/noto_sans_jp/RuntimeSansJP.ttf',
        'RobotoMono': 'assets/fonts/roboto_mono/RobotoMono.ttf',
      }.entries) {
        final families = manifest
            .where((item) => item['family'] == entry.key)
            .toList();
        expect(families.length, 1);
        expect(
          (families.single['fonts'] as List).map((font) => font['asset']),
          [entry.value],
        );
      }
    },
  );
  test(
    'bundled Japanese font covers all copy and stays below one megabyte',
    () {
      final directory = Directory('assets/fonts/noto_sans_jp');
      final coverage = File('${directory.path}/codepoints.txt')
          .readAsLinesSync()
          .map((line) => int.parse(line, radix: 16))
          .toSet();
      final missing = <int>{};
      for (final translations in GameText.copy.values) {
        for (final text in translations) {
          for (final point in text.runes) {
            if ((point >= 0x3000 && point <= 0x9fff ||
                    point >= 0xff00 && point <= 0xffef) &&
                !coverage.contains(point)) {
              missing.add(point);
            }
          }
        }
      }
      expect(
        missing.map(String.fromCharCode).join(),
        isEmpty,
        reason: 'Regenerate the bundled font with tool/subset_japanese_font.py',
      );
      expect(
        File('${directory.path}/RuntimeSansJP.ttf').lengthSync(),
        lessThan(1000000),
      );
    },
  );
}
