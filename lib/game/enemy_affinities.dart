import 'build.dart';
import 'combat_entities.dart';

/// Recommendations describe geometry and workload, never required counters.
extension EnemyAffinities on EnemyType {
  List<Upgrade> get compatibleFeatures => switch (this) {
    EnemyType.request => const [Upgrade.concurrency, Upgrade.garbageCollection],
    EnemyType.interrupt => const [
      Upgrade.lazyEvaluation,
      Upgrade.exceptionHandling,
    ],
    EnemyType.batch => const [
      Upgrade.patternMatching,
      Upgrade.garbageCollection,
      Upgrade.jitCompilation,
    ],
    EnemyType.allocation => const [Upgrade.asyncStream, Upgrade.oop],
    EnemyType.rpc => const [
      Upgrade.oop,
      Upgrade.patternMatching,
      Upgrade.exceptionHandling,
    ],
    EnemyType.forkBomb => const [Upgrade.garbageCollection, Upgrade.functional],
    EnemyType.memoryLeak => const [Upgrade.asyncStream, Upgrade.oop],
    EnemyType.timerEvent => const [
      Upgrade.asyncStream,
      Upgrade.exceptionHandling,
    ],
    EnemyType.deadlock => const [
      Upgrade.concurrency,
      Upgrade.oop,
      Upgrade.asyncStream,
    ],
    _ => const [],
  };
}
