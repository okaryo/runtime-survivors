import 'package:flame/components.dart';

enum EnemyType {
  request,
  interrupt,
  allocation,
  deadlock,
  rpc,
  forkBomb,
  bufferOverflow,
  scheduler,
  armoredAllocation,
  nullReference,
  duplicateRequest,
  batch,
  lockNode,
  memoryLeak,
  timerEvent,
}

extension EnemyAvailability on EnemyType {
  bool get isSpecialist => const {
    EnemyType.rpc,
    EnemyType.forkBomb,
    EnemyType.memoryLeak,
    EnemyType.timerEvent,
  }.contains(this);

  bool get isDiscoverable => const {
    EnemyType.request,
    EnemyType.interrupt,
    EnemyType.allocation,
    EnemyType.batch,
    EnemyType.rpc,
    EnemyType.forkBomb,
    EnemyType.deadlock,
    EnemyType.memoryLeak,
    EnemyType.timerEvent,
  }.contains(this);
}

class TaskEnemy {
  TaskEnemy(
    this.position, {
    this.kind = 0,
    this.health = 22,
    this.summoned = false,
    this.owner,
    this.inputVariant = 0,
    this.generation = 0,
    this.reinforced = false,
  }) : maxHealth = health,
       assert(
         !reinforced || (!summoned && EnemyType.values[kind].isSpecialist),
       ) {
    attackCooldown = switch (type) {
      EnemyType.rpc => 0.35,
      EnemyType.timerEvent => 0,
      EnemyType.memoryLeak => 0.6,
      EnemyType.forkBomb when !summoned => 0.8,
      _ => 1.5,
    };
  }
  final Vector2 position;
  final int kind;
  final int inputVariant;
  final int generation;
  final formationOffset = Vector2.zero();
  int retryCount = 0;
  int cycleCount = 0;
  List<double> pulseGaps = const [];
  final bool summoned;
  final bool reinforced;
  final TaskEnemy? owner;
  EnemyType get type => EnemyType.values[kind];
  double movementMultiplier = 1;
  double attackCooldown = 1.5;
  double health;
  final double maxHealth;
  double flash = 0;
  double telegraphRemaining = 0;
  final chargeDirection = Vector2.zero();
  bool get alive => health > 0;
  double get radius => baseRadius * (reinforced ? 1.25 : 1);
  double get baseRadius => type == EnemyType.deadlock
      ? 28
      : type == EnemyType.allocation
      ? 21
      : type == EnemyType.forkBomb
      ? (summoned ? 9 : 18)
      : type == EnemyType.memoryLeak
      ? 17
      : type == EnemyType.timerEvent
      ? 16
      : 13;
  double get speed => switch (type) {
    EnemyType.interrupt => 103,
    EnemyType.allocation => 40,
    EnemyType.batch => 48,
    EnemyType.rpc => 46,
    EnemyType.forkBomb => summoned ? 68 : 34,
    EnemyType.lockNode || EnemyType.deadlock => 0,
    EnemyType.memoryLeak => 32,
    EnemyType.timerEvent => 38,
    _ => 57,
  };

  /// Specialists give ground when pursued; summoned copies still rush in.
  ({double near, double far})? get preferredRange => switch (type) {
    EnemyType.rpc => (near: 230, far: 320),
    EnemyType.forkBomb when !summoned => (near: 190, far: 260),
    EnemyType.memoryLeak => (near: 260, far: 330),
    EnemyType.timerEvent => (near: 210, far: 280),
    _ => null,
  };

  double get jitGain => _baseJitGain * (reinforced ? 1.5 : 1);
  double get _baseJitGain => summoned
      ? 0.5
      : switch (type) {
          EnemyType.request => 3,
          EnemyType.interrupt => 4,
          EnemyType.batch => 2,
          EnemyType.allocation => 10,
          EnemyType.rpc => 9,
          EnemyType.timerEvent => 10,
          EnemyType.memoryLeak => 12,
          EnemyType.forkBomb => 14,
          EnemyType.lockNode => 4,
          EnemyType.deadlock => 30,
          _ => 0,
        };

  int get experienceValue =>
      (type == EnemyType.lockNode
          ? 3
          : summoned
          ? 1
          : type == EnemyType.deadlock
          ? 45
          : type == EnemyType.allocation
          ? 9
          : type == EnemyType.memoryLeak || type == EnemyType.timerEvent
          ? 7
          : 4) *
      (reinforced ? 2 : 1);
}

enum InstructionKind { base, object, chain }

class Instruction {
  Instruction(
    this.position,
    this.target,
    this.damage, {
    this.kind = InstructionKind.base,
    this.jumps = 0,
    Set<TaskEnemy>? visited,
  }) : visited = visited ?? {target};
  final Vector2 position;
  final TaskEnemy target;
  final double damage;
  final InstructionKind kind;
  final int jumps;
  final Set<TaskEnemy> visited;
  double life = 1.5;
}

class RuntimeObject {
  RuntimeObject(this.index, Vector2 player) : position = player.clone();
  final int index;
  final Vector2 position;
  double attackTimer = 0;
}

class Experience {
  Experience(this.position, this.value);
  final Vector2 position;
  final int value;
}

class RunEffect {
  RunEffect(
    this.position, {
    this.pulse = false,
    this.radius = 22,
    this.healing = false,
    this.optimized = false,
    this.collection = false,
    this.counter = false,
    this.recoveredMemory = 0,
    this.source,
  });
  final Vector2 position;
  final bool pulse;
  final bool healing;
  final bool optimized;
  final bool collection;
  final bool counter;
  final double recoveredMemory;
  final Vector2? source;
  double get duration => recoveredMemory > 0
      ? 0.9
      : counter
      ? 0.65
      : collection
      ? 0.75
      : 0.5;
  final double radius;
  late double life = duration;
}

/// A fixed trajectory shared by hostile shots and piercing player attacks.
class LinearProjectile {
  LinearProjectile(
    this.position,
    this.velocity, {
    required this.damage,
    this.hostile = true,
    this.life = 4,
    this.radius = 6,
    this.remainingDistance = double.infinity,
  });
  final Vector2 position;
  final Vector2 velocity;
  final double damage;
  final bool hostile;
  final double radius;
  double life;
  double remainingDistance;
  final Set<TaskEnemy> hit = {};
}

/// Swept collision avoids tunneling through small targets at high speed.
bool crossesCircle(Vector2 from, Vector2 to, Vector2 center, double radius) {
  final segment = to - from;
  final t = segment.length2 == 0
      ? 0.0
      : ((center - from).dot(segment) / segment.length2).clamp(0.0, 1.0);
  return (from + segment * t).distanceToSquared(center) <= radius * radius;
}

/// A delayed blast records a fixed point; moving away is always a counter.
class DangerZone {
  DangerZone(
    this.position, {
    this.radius = 75,
    this.damage = 18,
    double warning = 1.1,
  }) : remaining = warning,
       duration = warning;
  final Vector2 position;
  final double radius;
  final double damage;
  final double duration;
  double remaining;
}
