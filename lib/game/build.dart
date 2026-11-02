import 'dart:math';

enum TypingPolicy { staticTyping, dynamicTyping }

enum Upgrade {
  garbageCollection,
  concurrency,
  oop,
  functional,
  memory,
  clock,
  cache,
  compiler,
  nullSafety,
  patternMatching,
  pipeline,
  bandwidth,
  lazyEvaluation,
  memoization,
  jitCompilation,
  ownership,
  spatialIndex,
  coprocessor,
  memoryProtection,
}

extension UpgradeInfo on Upgrade {
  int? get maxRank => isFeature
      ? 4
      : switch (this) {
          Upgrade.pipeline => 16,
          Upgrade.bandwidth => 7,
          Upgrade.spatialIndex => 6,
          Upgrade.coprocessor => 10,
          Upgrade.memoryProtection => 6,
          _ => null,
        };

  Set<Upgrade> get requiresAny => switch (this) {
    Upgrade.spatialIndex => {Upgrade.garbageCollection, Upgrade.lazyEvaluation},
    Upgrade.coprocessor => {Upgrade.oop},
    _ => const {},
  };

  String get symbol => switch (this) {
    Upgrade.garbageCollection => 'GC',
    Upgrade.concurrency => '&&',
    Upgrade.oop => '{}',
    Upgrade.functional => 'λ',
    Upgrade.memory => 'MEM',
    Upgrade.clock => 'Hz',
    Upgrade.cache => r'$',
    Upgrade.compiler => '-O',
    Upgrade.nullSafety => '?',
    Upgrade.patternMatching => '=>',
    Upgrade.pipeline => '>>',
    Upgrade.bandwidth => '~>',
    Upgrade.lazyEvaluation => '...',
    Upgrade.memoization => 'M',
    Upgrade.jitCompilation => 'JIT',
    Upgrade.ownership => '&',
    Upgrade.spatialIndex => 'R',
    Upgrade.coprocessor => 'Co',
    Upgrade.memoryProtection => '#',
  };

  bool get isFeature => switch (this) {
    Upgrade.garbageCollection ||
    Upgrade.concurrency ||
    Upgrade.oop ||
    Upgrade.functional ||
    Upgrade.nullSafety ||
    Upgrade.patternMatching ||
    Upgrade.lazyEvaluation ||
    Upgrade.memoization ||
    Upgrade.jitCompilation ||
    Upgrade.ownership => true,
    _ => false,
  };
}

/// Shared stat formulas for live combat and immutable upgrade snapshots.
class BuildStats {
  BuildStats.live(this._ranks);
  BuildStats.snapshot(
    Map<Upgrade, int> ranks, {
    this.policy,
    this.dynamicBoost = false,
  }) : _ranks = Map.unmodifiable(ranks);
  final Map<Upgrade, int> _ranks;
  TypingPolicy? policy;
  bool dynamicBoost = false;
  int rank(Upgrade upgrade) => _ranks[upgrade] ?? 0;
  double get maxHealth =>
      100 +
      25.0 * rank(Upgrade.memory) -
      5.0 * rank(Upgrade.oop) -
      8.0 * rank(Upgrade.nullSafety);
  double get speed => 185.0 * pow(1.12, rank(Upgrade.clock));
  double get pickupRadius =>
      66 + 35.0 * rank(Upgrade.cache) - 8.0 * rank(Upgrade.ownership);
  double get attackRange =>
      300 + 20.0 * rank(Upgrade.cache) - 15.0 * rank(Upgrade.functional);
  double get objectDamage => 16 + rank(Upgrade.oop) * 4.0;
  double get objectInterval =>
      max(0.3, 0.9 * pow(0.9, rank(Upgrade.coprocessor)));
  double get chainRadius => 155;
  double get attackDamage =>
      24.0 *
      pow(1.25, rank(Upgrade.compiler)) *
      pow(0.88, rank(Upgrade.concurrency)) *
      (policy == TypingPolicy.staticTyping ? 0.9 : 1.0) *
      (rank(Upgrade.memoization) > 0 ? 0.9 : 1.0) *
      (rank(Upgrade.jitCompilation) > 0 ? 0.85 : 1.0);
  double get attackInterval => max(
    0.12,
    (0.62 + rank(Upgrade.garbageCollection) * 0.08) *
        pow(0.9, rank(Upgrade.pipeline)) /
        (dynamicBoost ? 1.3 : 1.0),
  );
  double get projectileSpeed =>
      min(1600.0, 640.0 * pow(1.15, rank(Upgrade.bandwidth)));
  double get shieldCooldown => 9.0 - rank(Upgrade.nullSafety);
  double get patternDamage => 30.0 + rank(Upgrade.patternMatching) * 12;
  double get patternRadius => 4.0 + rank(Upgrade.patternMatching) * 2;
  double get patternInterval => 3.2;
  int get targetCount => 1 + rank(Upgrade.concurrency);
  double get areaScale => pow(1.15, rank(Upgrade.spatialIndex)).toDouble();
  double get gcRadius =>
      (115 + rank(Upgrade.garbageCollection) * 18.0) * areaScale;
  double get slowRadius =>
      (90 + rank(Upgrade.lazyEvaluation) * 15.0) * areaScale;
  double get slowMultiplier => 0.75 - rank(Upgrade.lazyEvaluation) * 0.05;
  double get echoRatio => 0.55 + rank(Upgrade.memoization) * 0.10;
  double get jitPerStack => rank(Upgrade.jitCompilation) * 0.06;
  double get ownershipHeal => 1.0 + rank(Upgrade.ownership);
  double get ownershipCap => 4.0 + rank(Upgrade.ownership) * 2;
  double get ownershipRadius => 105;
  double get hitInvulnerability => 0.65 + rank(Upgrade.memoryProtection) * 0.1;
  double get gcDamage => 22 + rank(Upgrade.garbageCollection) * 14.0;
}

class UpgradePreview {
  const UpgradePreview({
    required this.upgrade,
    required this.before,
    required this.after,
    required this.beforeHealth,
    required this.afterHealth,
  });
  final Upgrade upgrade;
  final BuildStats before;
  final BuildStats after;
  final double beforeHealth;
  final double afterHealth;
}
