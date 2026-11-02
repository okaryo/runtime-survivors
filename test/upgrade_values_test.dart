import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/run_state.dart';
import 'package:runtime_survivors/l10n/game_text.dart';

void main() {
  for (final language in ['ja', 'en']) {
    final text = GameText(language);
    test(
      '$language: new abilities show standalone values; existing stats compare',
      () {
        final run = RunState()..start();
        final gc = text.comparisons(run.preview(Upgrade.garbageCollection));
        expect(gc.map((c) => c.values), ['36', '133', '0.62s → 0.70s']);
        final oop = text.comparisons(run.preview(Upgrade.oop));
        expect(oop.map((c) => c.values), ['1', '20', '100/100 → 95/95']);
        final fp = text.comparisons(run.preview(Upgrade.functional));
        expect(fp.map((c) => c.values), ['1', '300 → 285']);
        final concurrency = text.comparisons(run.preview(Upgrade.concurrency));
        expect(concurrency.map((c) => c.values), ['1 → 2', '24.0 → 21.1']);
        for (final upgrade in Upgrade.values.where((u) => !u.isFeature)) {
          expect(
            text
                .comparisons(run.preview(upgrade))
                .every((c) => c.values.contains(' → ')),
            isTrue,
          );
        }
      },
    );
    test('$language: later ranks compare the existing ability values', () {
      final run = RunState()..start();
      run.upgrades.addAll({for (final upgrade in Upgrade.values) upgrade: 1});
      expect(
        text
            .comparisons(run.preview(Upgrade.garbageCollection))
            .take(2)
            .map((c) => c.values),
        ['36 → 50', '133 → 151'],
      );
      expect(
        text.comparisons(run.preview(Upgrade.oop)).take(2).map((c) => c.values),
        ['1 → 2', '20 → 24'],
      );
      expect(
        text.comparisons(run.preview(Upgrade.functional)).first.values,
        '1 → 2',
      );
    });
  }
}
