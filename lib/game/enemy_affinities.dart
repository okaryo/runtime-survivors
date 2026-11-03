import 'build.dart';
import 'combat_entities.dart';

/// Recommendations describe geometry and workload, never required counters.
extension EnemyAffinities on EnemyType {
  List<Upgrade> get compatibleFeatures => switch (this) {
    EnemyType.request => const [Upgrade.memoization, Upgrade.jitCompilation],
    EnemyType.interrupt => const [Upgrade.lazyEvaluation, Upgrade.concurrency],
    EnemyType.batch => const [
      Upgrade.patternMatching,
      Upgrade.garbageCollection,
      Upgrade.memoization,
      Upgrade.jitCompilation,
    ],
    EnemyType.allocation => const [Upgrade.asyncStream, Upgrade.oop],
    EnemyType.rpc => const [Upgrade.oop, Upgrade.patternMatching],
    EnemyType.forkBomb => const [Upgrade.garbageCollection, Upgrade.functional],
    EnemyType.memoryLeak => const [Upgrade.asyncStream, Upgrade.oop],
    EnemyType.timerEvent => const [Upgrade.asyncStream, Upgrade.oop],
    EnemyType.deadlock => const [
      Upgrade.concurrency,
      Upgrade.oop,
      Upgrade.asyncStream,
    ],
    _ => const [],
  };
}
