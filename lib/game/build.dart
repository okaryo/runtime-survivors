import 'dart:math';

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
  asyncStream,
}

extension UpgradeInfo on Upgrade {
  int get maxRank => isFeature ? 4 : 6;

  // Stable IDs retain discovery records for abilities removed from this prototype.
  bool get isAvailable =>
      this != Upgrade.pipeline &&
      this != Upgrade.coprocessor &&
      this != Upgrade.nullSafety;

  Set<Upgrade> get requiresAny => const {};

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
    Upgrade.asyncStream => '~',
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
    Upgrade.ownership ||
    Upgrade.asyncStream => true,
    _ => false,
  };
}

/// Shared stat formulas for live combat and immutable upgrade snapshots.
class BuildStats {
  BuildStats.live(this._ranks);
  BuildStats.snapshot(Map<Upgrade, int> ranks, {this.jitCharge = 0})
    : _ranks = Map.unmodifiable(ranks);
  final Map<Upgrade, int> _ranks;
  double jitCharge = 0;
  int rank(Upgrade upgrade) => _ranks[upgrade] ?? 0;
  double get reservedMemory =>
      8.0 * rank(Upgrade.memoization) + 6.0 * rank(Upgrade.oop);
  double get maxHealth => 100 + 25.0 * rank(Upgrade.memory) - reservedMemory;
  double get speed => 185.0 * (1 + 0.08 * rank(Upgrade.clock));
  double get pickupRadius => 66 + 22.0 * rank(Upgrade.cache);
  double get attackRange => (300 + 12.0 * rank(Upgrade.cache)) * areaScale;
  double get cooldownScale => pow(0.92, rank(Upgrade.compiler)).toDouble();
  double get objectDamage => 20 + rank(Upgrade.oop) * 6.0;
  double get objectInterval => 0.9 * cooldownScale;
  double get chainRadius => 155 * areaScale;
  double get chainRetention => 0.85;
  double get compositionDelay => rank(Upgrade.functional) * 0.04;
  double get objectRange => 235 * areaScale;
  double get attackDamage => 24.0 * pow(0.92, rank(Upgrade.concurrency));
  double get jitSpeedBonus => 0.65 + rank(Upgrade.jitCompilation) * 0.25;
  double get attackInterval => max(
    0.12,
    (0.62 + compositionDelay) *
        cooldownScale /
        (1 +
            (rank(Upgrade.jitCompilation) > 0
                ? jitSpeedBonus * jitCharge / 100
                : 0)),
  );
  double get projectileSpeed =>
      min(1600.0, 640.0 * pow(1.15, rank(Upgrade.bandwidth)));
  double get shieldCooldown => 9.0 - rank(Upgrade.nullSafety);
  double get nullDamage => 18.0 + rank(Upgrade.nullSafety) * 10;
  double get nullRadius => 95 + rank(Upgrade.nullSafety) * 8.0;
  double get nullInterval => 1.8 * cooldownScale;
  double get patternDamage => 30.0 + rank(Upgrade.patternMatching) * 12;
  double get patternRadius =>
      (4.0 + rank(Upgrade.patternMatching) * 2) * areaScale;
  double get patternInterval => 2.8 * cooldownScale;
  int get targetCount => 1 + rank(Upgrade.concurrency);
  double get areaScale => 1 + 0.10 * rank(Upgrade.spatialIndex);
  double get gcRadius =>
      (115 + rank(Upgrade.garbageCollection) * 18.0) * areaScale;
  double get gcDamage => 30 + rank(Upgrade.garbageCollection) * 18.0;
  double get gcPause => 0.18;
  double get gcInterval => 3 * cooldownScale;
  double get slowRadius =>
      (90 + rank(Upgrade.lazyEvaluation) * 15.0) * areaScale;
  double get slowMultiplier => 0.75 - rank(Upgrade.lazyEvaluation) * 0.05;
  double get lazyDamage => 48 + rank(Upgrade.lazyEvaluation) * 20.0;
  double get lazyInterval => 4 * cooldownScale;
  double get lazyTickDamage => lazyDamage * 0.2;
  double get memoDamage => 18 + rank(Upgrade.memoization) * 12.0;
  double get memoInterval => 1.5 * cooldownScale;
  double get ownershipDamage => 26 + rank(Upgrade.ownership) * 14.0;
  double get ownershipInterval => 1.6 * cooldownScale;
  double get ownershipHeal => 1.0 + rank(Upgrade.ownership);
  double get ownershipCap => 4.0 + rank(Upgrade.ownership) * 2;
  double get ownershipRadius => 105 * areaScale;
  double get streamDamage => 10 + rank(Upgrade.asyncStream) * 4.0;
  double get streamInterval => 0.25 * cooldownScale;
  int get streamConnections =>
      1 +
      (rank(Upgrade.asyncStream) >= 2 ? 1 : 0) +
      (rank(Upgrade.asyncStream) >= 4 ? 1 : 0);
  double get streamPreparation =>
      (0.26 - rank(Upgrade.asyncStream) * 0.04) * cooldownScale;
  double get hitInvulnerability => 0.65 + rank(Upgrade.memoryProtection) * 0.08;
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
