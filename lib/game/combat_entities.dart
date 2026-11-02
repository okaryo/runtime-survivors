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
}

class TaskEnemy {
  TaskEnemy(
    this.position, {
    this.kind = 0,
    this.health = 22,
    this.summoned = false,
    this.owner,
    this.inputVariant = 0,
  }) : maxHealth = health;
  final Vector2 position;
  final int kind;
  final int inputVariant;
  int get inputSignature => kind * 3 + inputVariant;
  final bool summoned;
  final TaskEnemy? owner;
  EnemyType get type => EnemyType.values[kind];
  final facing = Vector2(0, 1);
  bool supported = false;
  double movementMultiplier = 1;
  double get attackRate => supported ? 1.15 : 1;
  double armorFlash = 0;
  double attackCooldown = 1.5;
  double health;
  final double maxHealth;
  double flash = 0;
  double chargeCooldown = 2.2;
  double telegraphRemaining = 0;
  double chargeRemaining = 0;
  final chargeDirection = Vector2.zero();
  bool get alive => health > 0;
  double get radius => kind == 3
      ? 25
      : kind == 2 || kind == 8
      ? 18
      : 13;
  double get speed => switch (kind) {
    1 => 103,
    2 => 40,
    3 => 62,
    4 => 48,
    5 => 34,
    6 => 50,
    7 => 38,
    8 => 46,
    _ => 57,
  };
}

enum InstructionKind { base, object, chain, cached }

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
    this.dynamicCheck = false,
  });
  final Vector2 position;
  final bool pulse;
  final bool healing;
  final bool optimized;
  final bool dynamicCheck;
  final double radius;
  double life = 0.5;
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
    this.nullReference = false,
  });
  final Vector2 position;
  final Vector2 velocity;
  final double damage;
  final bool hostile;
  final bool nullReference;
  final double radius;
  double life;
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
