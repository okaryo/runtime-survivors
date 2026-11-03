import 'package:flutter_test/flutter_test.dart';
import 'package:runtime_survivors/game/build.dart';
import 'package:runtime_survivors/game/language_profile.dart';

void main() {
  test(
    'language affinities use feature investments without a typing choice',
    () {
      for (final build in [
        ('Go', {Upgrade.garbageCollection: 1, Upgrade.concurrency: 2}),
        ('Java', {Upgrade.garbageCollection: 1, Upgrade.oop: 3}),
        ('Scala', {Upgrade.oop: 1, Upgrade.functional: 2}),
        ('Rust', {Upgrade.ownership: 3}),
        (
          'Python',
          {Upgrade.garbageCollection: 1, Upgrade.exceptionHandling: 2},
        ),
        ('Ruby', {Upgrade.garbageCollection: 2, Upgrade.oop: 1}),
        ('JavaScript', {Upgrade.functional: 2, Upgrade.concurrency: 1}),
      ]) {
        expect(LanguageProfile.analyze(build.$2).language, build.$1);
      }
      expect(LanguageProfile.analyze({}).language, 'custom');
    },
  );
  test(
    'profile snapshots keep the completed language and explain its investments',
    () {
      final ranks = {Upgrade.garbageCollection: 1, Upgrade.oop: 3};
      final profile = LanguageProfile.analyze(ranks);
      ranks[Upgrade.oop] = 0;
      expect(profile.language, 'Java');
      expect(profile.dominantFeatures.first, Upgrade.oop);
      expect(profile.investments[Upgrade.oop], 3);
    },
  );
}
