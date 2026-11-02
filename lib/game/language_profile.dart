import 'build.dart';

/// Deliberately independent of damage formulas and encounter outcomes.
/// These are playful affinities, not claims of language equivalence.
class LanguageProfile {
  LanguageProfile._(this.language, this.policy, this.investments);
  final String language;
  final TypingPolicy? policy;
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

  factory LanguageProfile.analyze(
    TypingPolicy? policy,
    Map<Upgrade, int> ranks,
  ) {
    int rank(Upgrade u) => ranks[u] ?? 0;
    final total = ranks.entries
        .where((e) => e.key.isFeature)
        .fold(0, (sum, e) => sum + e.value);
    var language = 'custom';
    var bestScore = -1;
    if (total >= 3 && policy != null) {
      for (final archetype in _archetypes) {
        if (archetype.policy != policy ||
            !archetype.required.entries.every((e) => rank(e.key) >= e.value)) {
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
    return LanguageProfile._(language, policy, Map.unmodifiable(ranks));
  }
}

class _Archetype {
  const _Archetype(this.language, this.policy, this.required, this.weights);
  final String language;
  final TypingPolicy policy;
  final Map<Upgrade, int> required;
  final Map<Upgrade, int> weights;
}

const _archetypes = [
  _Archetype(
    'Go',
    TypingPolicy.staticTyping,
    {Upgrade.garbageCollection: 1, Upgrade.concurrency: 1},
    {Upgrade.garbageCollection: 1, Upgrade.concurrency: 3},
  ),
  _Archetype(
    'Java',
    TypingPolicy.staticTyping,
    {Upgrade.garbageCollection: 1, Upgrade.oop: 2},
    {Upgrade.garbageCollection: 1, Upgrade.oop: 3, Upgrade.jitCompilation: 1},
  ),
  _Archetype(
    'Scala',
    TypingPolicy.staticTyping,
    {Upgrade.oop: 1, Upgrade.functional: 2},
    {Upgrade.oop: 1, Upgrade.functional: 3, Upgrade.jitCompilation: 1},
  ),
  _Archetype(
    'Rust',
    TypingPolicy.staticTyping,
    {Upgrade.ownership: 2},
    {Upgrade.ownership: 3, Upgrade.nullSafety: 1},
  ),
  _Archetype(
    'Python',
    TypingPolicy.dynamicTyping,
    {Upgrade.garbageCollection: 1},
    {Upgrade.garbageCollection: 2, Upgrade.oop: 1, Upgrade.memoization: 1},
  ),
  _Archetype(
    'Ruby',
    TypingPolicy.dynamicTyping,
    {Upgrade.oop: 2},
    {Upgrade.oop: 3, Upgrade.garbageCollection: 1},
  ),
  _Archetype(
    'JavaScript',
    TypingPolicy.dynamicTyping,
    {Upgrade.functional: 1, Upgrade.concurrency: 1},
    {Upgrade.functional: 2, Upgrade.concurrency: 2, Upgrade.jitCompilation: 1},
  ),
];
