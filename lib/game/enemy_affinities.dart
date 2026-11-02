import 'build.dart';
import 'combat_entities.dart';

/// Tactical recommendations, not damage multipliers or weapon requirements.
extension EnemyAffinities on EnemyType {
  List<Upgrade> get compatibleFeatures => switch (this) {
    EnemyType.request || EnemyType.bufferOverflow => const [],
    EnemyType.interrupt => const [Upgrade.lazyEvaluation, Upgrade.concurrency],
    EnemyType.allocation ||
    EnemyType.deadlock => const [Upgrade.jitCompilation, Upgrade.memoization],
    EnemyType.rpc => const [Upgrade.nullSafety],
    EnemyType.forkBomb => const [
      Upgrade.garbageCollection,
      Upgrade.functional,
      Upgrade.patternMatching,
    ],
    EnemyType.scheduler => const [Upgrade.patternMatching, Upgrade.functional],
    EnemyType.armoredAllocation => const [
      Upgrade.garbageCollection,
      Upgrade.oop,
    ],
  };
}
