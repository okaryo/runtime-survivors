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
        expect(gc.map((c) => c.values), ['48', '133', '0.18s']);
        final oop = text.comparisons(run.preview(Upgrade.oop));
        expect(oop.map((c) => c.values), ['1', '20', '0.90s']);
        final fp = text.comparisons(run.preview(Upgrade.functional));
        expect(fp.map((c) => c.values), ['1']);
        final concurrency = text.comparisons(run.preview(Upgrade.concurrency));
        expect(concurrency.map((c) => c.values), ['1 → 2', '24 → 22.1']);
        for (final upgrade in Upgrade.values.where(
          (u) => u.isAvailable && !u.isFeature,
        )) {
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
      run.upgrades.addAll({
        for (final upgrade in [
          Upgrade.garbageCollection,
          Upgrade.concurrency,
          Upgrade.oop,
          Upgrade.functional,
        ])
          upgrade: 1,
      });
      expect(
        text
            .comparisons(run.preview(Upgrade.garbageCollection))
            .take(2)
            .map((c) => c.values),
        ['48 → 66', '133 → 151'],
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
