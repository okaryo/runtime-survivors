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
    final gc = rank(Upgrade.garbageCollection);
    final oop = rank(Upgrade.oop);
    final functional = rank(Upgrade.functional);
    final concurrency = rank(Upgrade.concurrency);
    final total = ranks.entries
        .where((e) => e.key.isFeature)
        .fold(0, (sum, e) => sum + e.value);
    var language = 'custom';
    if (total >= 3 && policy != null) {
      if (policy == TypingPolicy.staticTyping) {
        if (functional >= 2 && functional > oop && oop > 0) {
          language = 'Scala';
        } else if (oop >= 2 && oop > concurrency && gc > 0) {
          language = 'Java';
        } else if (gc > 0 && concurrency > 0) {
          language = 'Go';
        }
      } else {
        if (functional > 0 &&
            concurrency > 0 &&
            functional + concurrency >= 3) {
          language = 'JavaScript';
        } else if (oop >= 2 && oop > gc) {
          language = 'Ruby';
        } else if (gc > 0) {
          language = 'Python';
        }
      }
    }
    return LanguageProfile._(language, policy, Map.unmodifiable(ranks));
  }
}
