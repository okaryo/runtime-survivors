import 'build.dart';

/// Deliberately independent of damage formulas and encounter outcomes.
/// These are playful affinities, not claims of language equivalence.
class LanguageProfile {
  LanguageProfile._(this.language, this.investments);
  final String language;
  final Map<Upgrade, int> investments;
  List<Upgrade> get dominantFeatures {
    final features = investments.keys
        .where((u) => u.isFeature && investments[u]! > 0)
        .toList();
    features.sort((a, b) {
      final comparison = investments[b]!.compareTo(investments[a]!);
      return comparison != 0 ? comparison : a.index.compareTo(b.index);
    });
    return features.take(2).toList();
  }

  factory LanguageProfile.analyze(Map<Upgrade, int> ranks) {
    int rank(Upgrade u) => ranks[u] ?? 0;
    final total = ranks.entries
        .where((e) => e.key.isFeature)
        .fold(0, (sum, e) => sum + e.value);
    var language = 'custom';
    var bestScore = -1;
    if (total >= 3) {
      for (final archetype in _archetypes) {
        if (!archetype.required.entries.every((e) => rank(e.key) >= e.value)) {
          continue;
        }
        final score = archetype.weights.entries.fold(
          0,
          (sum, e) => sum + rank(e.key) * e.value,
        );
        if (score > bestScore) {
          bestScore = score;
          language = archetype.language;
        }
      }
    }
    return LanguageProfile._(language, Map.unmodifiable(ranks));
  }
}

class _Archetype {
  const _Archetype(this.language, this.required, this.weights);
  final String language;
  final Map<Upgrade, int> required;
  final Map<Upgrade, int> weights;
}

const _archetypes = [
  _Archetype(
    'Go',
    {Upgrade.garbageCollection: 1, Upgrade.concurrency: 1},
    {Upgrade.garbageCollection: 1, Upgrade.concurrency: 3},
  ),
  _Archetype(
    'Java',
    {Upgrade.garbageCollection: 1, Upgrade.oop: 2},
    {Upgrade.garbageCollection: 1, Upgrade.oop: 3, Upgrade.jitCompilation: 1},
  ),
  _Archetype(
    'Scala',
    {Upgrade.oop: 1, Upgrade.functional: 2},
    {Upgrade.oop: 1, Upgrade.functional: 3, Upgrade.jitCompilation: 1},
  ),
  _Archetype(
    'Rust',
    {Upgrade.ownership: 2},
    {Upgrade.ownership: 3, Upgrade.functional: 1},
  ),
  _Archetype(
    'Python',
    {Upgrade.garbageCollection: 1, Upgrade.exceptionHandling: 1},
    {
      Upgrade.garbageCollection: 2,
      Upgrade.oop: 1,
      Upgrade.exceptionHandling: 1,
    },
  ),
  _Archetype(
    'Ruby',
    {Upgrade.garbageCollection: 2, Upgrade.oop: 1},
    {Upgrade.oop: 2, Upgrade.garbageCollection: 2},
  ),
  _Archetype(
    'JavaScript',
    {Upgrade.functional: 1, Upgrade.concurrency: 1},
    {Upgrade.functional: 2, Upgrade.concurrency: 2, Upgrade.jitCompilation: 1},
  ),
];
