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
  int get maxRank => isFeature ? 4 : 6;

  // Kept as a stable discovery ID; its cooldown role now belongs to Compiler.
  bool get isAvailable => this != Upgrade.pipeline;

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
    Upgrade.patternMatching => 'SIMD',
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

enum PolicyUpgrade { coverage, potency }

/// Shared stat formulas for live combat and immutable upgrade snapshots.
class BuildStats {
  BuildStats.live(this._ranks);
  BuildStats.snapshot(
    Map<Upgrade, int> ranks, {
    this.policy,
    this.policyCoverage = 0,
    this.policyPotency = 0,
    this.jitOptimized = false,
  }) : _ranks = Map.unmodifiable(ranks);
  final Map<Upgrade, int> _ranks;
  TypingPolicy? policy;
  int policyCoverage = 0;
  int policyPotency = 0;
  bool jitOptimized = false;
  int rank(Upgrade upgrade) => _ranks[upgrade] ?? 0;
  double get maxHealth => 100 + 25.0 * rank(Upgrade.memory);
  double get speed => 185.0 * (1 + 0.08 * rank(Upgrade.clock));
  double get pickupRadius => 66 + 22.0 * rank(Upgrade.cache);
  double get attackRange => 300 + 12.0 * rank(Upgrade.cache);
  double get cooldownScale => pow(0.92, rank(Upgrade.compiler)).toDouble();
  double get objectDamage => 16 + rank(Upgrade.oop) * 4.0;
  double get objectInterval =>
      max(0.25, 0.9 * pow(0.92, rank(Upgrade.coprocessor)) * cooldownScale);
  double get chainRadius => 155;
  double get attackDamage => 24;
  double get jitSpeedBonus => 0.25 + rank(Upgrade.jitCompilation) * 0.15;
  double get attackInterval =>
      max(0.12, 0.62 * cooldownScale / (jitOptimized ? 1 + jitSpeedBonus : 1));
  double get projectileSpeed =>
      min(1600.0, 640.0 * pow(1.15, rank(Upgrade.bandwidth)));
  double get shieldCooldown => 9.0 - rank(Upgrade.nullSafety);
  double get nullDamage => 18.0 + rank(Upgrade.nullSafety) * 10;
  double get nullRadius => 95 + rank(Upgrade.nullSafety) * 8.0;
  double get nullInterval => 1.8 * cooldownScale;
  double get patternDamage => 30.0 + rank(Upgrade.patternMatching) * 12;
  double get patternRadius => 4.0 + rank(Upgrade.patternMatching) * 2;
  double get patternInterval => 2.8 * cooldownScale;
  int get targetCount => 1 + rank(Upgrade.concurrency);
  double get areaScale => 1 + 0.10 * rank(Upgrade.spatialIndex);
  double get gcRadius =>
      (115 + rank(Upgrade.garbageCollection) * 18.0) * areaScale;
  double get gcDamage => 22 + rank(Upgrade.garbageCollection) * 14.0;
  double get gcInterval => 3 * cooldownScale;
  double get slowRadius =>
      (90 + rank(Upgrade.lazyEvaluation) * 15.0) * areaScale;
  double get slowMultiplier => 0.75 - rank(Upgrade.lazyEvaluation) * 0.05;
  double get lazyDamage => 30 + rank(Upgrade.lazyEvaluation) * 16.0;
  double get lazyInterval => 4 * cooldownScale;
  double get memoDamage => 18 + rank(Upgrade.memoization) * 12.0;
  double get memoInterval => 1.5 * cooldownScale;
  double get ownershipDamage => 20 + rank(Upgrade.ownership) * 12.0;
  double get ownershipInterval => 1.6 * cooldownScale;
  double get ownershipHeal => 1.0 + rank(Upgrade.ownership);
  double get ownershipCap => 4.0 + rank(Upgrade.ownership) * 2;
  double get ownershipRadius => 105;
  double get hitInvulnerability => 0.65 + rank(Upgrade.memoryProtection) * 0.08;
  int get scanTargets => 2 + policyCoverage * 2;
  int get dynamicSpread => policyCoverage;
  double get policyBonus =>
      (policy == TypingPolicy.staticTyping ? 0.5 : 0.3) + policyPotency * 0.15;
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
