import 'build.dart';
import 'combat_entities.dart';

/// Explains useful behavior; specialist bonuses never require a weapon.
extension EnemyAffinities on EnemyType {
  List<Upgrade> get compatibleFeatures => switch (this) {
    EnemyType.request || EnemyType.bufferOverflow => const [],
    EnemyType.interrupt => const [Upgrade.lazyEvaluation, Upgrade.concurrency],
    EnemyType.allocation ||
    EnemyType.deadlock => const [Upgrade.jitCompilation],
    EnemyType.rpc => const [Upgrade.patternMatching, Upgrade.oop],
    EnemyType.nullReference => const [Upgrade.nullSafety],
    EnemyType.duplicateRequest => const [
      Upgrade.memoization,
      Upgrade.concurrency,
    ],
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
